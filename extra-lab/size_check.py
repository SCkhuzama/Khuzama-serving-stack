import sys

def parse_size_to_mb(size_str):
    size_str = size_str.strip()
    if size_str.endswith("GB"):
        return float(size_str[:-2]) * 1024
    if size_str.endswith("MB"):
        return float(size_str[:-2])
    if size_str.endswith("kB"):
        return float(size_str[:-2]) / 1024
    if size_str.endswith("B"):
        return float(size_str[:-1]) / (1024 * 1024)
    raise ValueError(f"unrecognized size format: {size_str}")

naive_mb = parse_size_to_mb(sys.argv[1])
multi_mb = parse_size_to_mb(sys.argv[2])
target_mb = float(sys.argv[3])
min_pct = float(sys.argv[4])

savings_mb = naive_mb - multi_mb
savings_pct = (savings_mb / naive_mb) * 100 if naive_mb > 0 else 0

fits_target = multi_mb <= target_mb
enough_savings = savings_pct >= min_pct

print(f"{multi_mb:.1f}|{savings_pct:.1f}|{int(fits_target)}|{int(enough_savings)}")