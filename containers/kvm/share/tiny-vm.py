"""練習機の中の KVM（入れ子の仮想化）に、小さな仮想マシンを1つ作って動かす（練習機の中の root で動かす）。
  檻（lab@host）から: ssh linuc sudo python3 - < /usr/local/share/lab-kvm/tiny-vm.py
仮想マシンのメモリに置く命令は6つだけ（実モード）:
  mov al,2 / add al,2 / add al,'0' / mov dx,0x3f8 / out dx,al / hlt
  2+2 を計算して、文字 '4' を装置の番号 0x3f8（シリアル）に書き、hlt で止まる。
  装置への書き込みと hlt では、KVM が仮想マシンを止めて、このプログラムに知らせる（KVM_EXIT_IO・KVM_EXIT_HLT）。
仮想マシンを作る前と後に、CPU 0 の AMD-V のスイッチ（EFER という設定の SVME。MSR 0xC0000080 の bit 12）も読む。
"""
import ctypes, fcntl, mmap, os, struct, subprocess


def svme():
    f = os.open("/dev/cpu/0/msr", os.O_RDONLY)
    v = int.from_bytes(os.pread(f, 8, 0xC0000080), "little")
    os.close(f)
    return (v >> 12) & 1


subprocess.run(["modprobe", "msr"], check=True)
print("AMD-V のスイッチ（EFER.SVME）:", svme())
kvm = os.open("/dev/kvm", os.O_RDWR)
vm = fcntl.ioctl(kvm, 0xAE01, 0)                                   # KVM_CREATE_VM
print("KVM_CREATE_VM → 仮想マシンを作った")
print("AMD-V のスイッチ（EFER.SVME）:", svme())
mem = mmap.mmap(-1, 0x10000)                                       # 仮想マシンのメモリ（64KiB）
code = bytes([0xB0, 0x02, 0x04, 0x02, 0x04, 0x30, 0xBA, 0xF8, 0x03, 0xEE, 0xF4])
mem[0x1000:0x1000 + len(code)] = code
addr = ctypes.addressof(ctypes.c_char.from_buffer(mem))
fcntl.ioctl(vm, 0x4020AE46, struct.pack("<IIQQQ", 0, 0, 0, 0x10000, addr))   # KVM_SET_USER_MEMORY_REGION
cpu = fcntl.ioctl(vm, 0xAE41, 0)                                   # KVM_CREATE_VCPU
run = mmap.mmap(cpu, fcntl.ioctl(kvm, 0xAE04, 0))                  # KVM_GET_VCPU_MMAP_SIZE
sregs = bytearray(312)
fcntl.ioctl(cpu, 0x8138AE83, sregs)                                # KVM_GET_SREGS
struct.pack_into("<Q", sregs, 0, 0)                                # cs の base を 0
struct.pack_into("<H", sregs, 12, 0)                               # cs の selector を 0
fcntl.ioctl(cpu, 0x4138AE84, bytes(sregs))                         # KVM_SET_SREGS
regs = bytearray(144)
struct.pack_into("<QQ", regs, 128, 0x1000, 0x2)                    # rip = 0x1000、rflags = 2
fcntl.ioctl(cpu, 0x4090AE82, bytes(regs))                          # KVM_SET_REGS
while True:
    fcntl.ioctl(cpu, 0xAE80, 0)                                    # KVM_RUN
    reason = struct.unpack_from("<I", run, 8)[0]
    if reason == 2:                                                # KVM_EXIT_IO
        size, port, off = run[33], struct.unpack_from("<H", run, 34)[0], struct.unpack_from("<Q", run, 40)[0]
        print(f"KVM_RUN → KVM_EXIT_IO（装置 {port:#x} に {run[off:off + size]!r} を書いた）")
    elif reason == 5:                                              # KVM_EXIT_HLT
        print("KVM_RUN → KVM_EXIT_HLT（hlt で止まった）")
        break
    else:
        print("KVM_RUN → 止まった理由", reason)
        break
