import sys

def bin2hex(bin_path, hex_path):
    with open(bin_path, "rb") as f:
        data = f.read()
    # Pad to 4-byte boundary
    if len(data) % 4 != 0:
        data += b'\x00' * (4 - (len(data) % 4))
    with open(hex_path, "w") as out:
        for i in range(0, len(data), 4):
            word = int.from_bytes(data[i:i+4], byteorder="little")
            out.write(f"{word:08x}\n")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: bin2hex.py <input.bin> <output.hex>")
        sys.exit(1)
    bin2hex(sys.argv[1], sys.argv[2])
