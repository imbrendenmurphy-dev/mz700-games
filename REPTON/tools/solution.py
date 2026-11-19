"""solution.py - a complete solution of SKINK, played by tools/solve.py.

Each entry is one visit to a region: (region key, commands).  Commands:
    ('go', x, y)            pilot to a cell (safe path, waits when needed)
    ('into', x, y)          pilot next to a cell and step into it (switch,
                            transporter, gate)
    ('mv', 'R3 U D L')      exact moves (L U R D, '.' = wait), no checks
    ('seq', 'U D5 L')       exact moves, started only when they are safe
    ('wait', n)             stand still
    ('until', x, y, 'MONSTER', limit)   wait until that cell holds it
    ('collect', kinds, box) visit every reachable collectable
Coordinates are interior map coordinates (x 0-29, y 0-21).
"""
ALL = ('GEM', 'PIECE', 'CROWN', 'KEY')

SOLUTION = [
    ('A', [('collect', ALL, (0, 0, 29, 15)), ('into', 1, 5)]),
    ('B', [
        ('collect', ALL, (0, 0, 29, 13)),
        ('go', 22, 21), ('mv', 'R U D L'),
        ('go', 23, 18), ('into', 23, 17),
        ('collect', ALL),
        ('into', 0, 0)]),
    ('A', [('into', 27, 5)]),
    ('C', [
        ('go', 8, 5), ('go', 7, 5), ('mv', 'U D R'),
        ('until', 11, 3, 'GEM', 300), ('go', 11, 3),
        ('go', 24, 10), ('go', 24, 8), ('mv', 'R L'), ('go', 24, 6),
        ('seq', 'U D5 L'),
        ('until', 26, 8, 'GEM', 300),
        ('collect', ALL, (13, 0, 29, 12)),
        ('go', 10, 12), ('seq', 'D3'),
        ('go', 10, 17), ('into', 10, 18),
        ('go', 27, 16), ('seq', 'U U D D D'),
        ('until', 28, 14, 'GEM', 300),
        ('collect', ALL),
        ('into', 0, 0)]),
    ('A', [('collect', ALL, (0, 16, 9, 18)), ('into', 1, 17)]),
    ('D', [
        ('collect', ALL, (0, 0, 29, 6)),
        ('go', 2, 8), ('go', 5, 8), ('mv', 'R R . R R R R . R'),
        ('collect', ALL, (0, 8, 29, 8)),
        ('go', 3, 15), ('mv', 'R12'), ('mv', 'R'), ('into', 17, 15)]),
    ('D', [
        ('collect', ALL),
        ('go', 21, 19), ('into', 20, 19),
        ('collect', ALL),
        ('into', 1, 1)]),
    ('A', [('collect', ALL, (20, 16, 29, 18)), ('into', 28, 17)]),
    ('E', [
        ('go', 2, 2), ('go', 2, 3), ('mv', 'R U R R R D'),
        ('until', 4, 7, 'MONSTER', 300), ('mv', 'L'),
        ('wait', 12),
        ('go', 9, 2), ('go', 9, 3), ('mv', 'R'),
        ('go', 10, 0), ('go', 12, 0), ('go', 12, 2), ('go', 13, 2), ('go', 13, 3), ('mv', 'L'),
        ('go', 12, 2),
        ('until', 11, 7, 'MONSTER', 300), ('mv', 'L R'),
        ('wait', 12),
        ('go', 1, 13), ('go', 2, 13), ('mv', 'R R . R R R R'), ('mv', 'U'),
        ('until', 9, 16, 'MONSTER', 300), ('mv', 'R L'),
        ('wait', 12),
        ('collect', ALL),
        ('into', 14, 19),
        ('into', 0, 0)]),
    ('A', [('collect', ALL), ('into', 14, 12)]),
]
