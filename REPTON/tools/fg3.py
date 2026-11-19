from findglyph import ALL
def chamfer(corner, k):
    rows = []
    for y in range(8):
        r = ''
        for x in range(8):
            xx = x if corner in ('TL', 'BL') else 7 - x
            yy = y if corner in ('TL', 'TR') else 7 - y
            r += '.' if xx + yy < k else '#'
        rows.append(r)
    return rows
def bestinv(target, n=5):
    t = [[1 if ch == '#' else 0 for ch in row] for row in target]
    sc = []
    for g in range(512):
        b = ALL[g]
        d = sum(b[y][x] != t[y][x] for y in range(8) for x in range(8))
        sc.append((d, '%03X' % g))
        sc.append((64 - d, '%03X~' % g))
    sc.sort()
    return sc[:n]
if __name__ == "__main__":
  for k in (3, 4, 5):
      for c in ('TL', 'TR', 'BL', 'BR'):
        print(k, c, bestinv(chamfer(c, k)))
