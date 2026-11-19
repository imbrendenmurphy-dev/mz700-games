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
    ('A', [('into', 1, 20)]),
    ('F', [
        ('collect', ALL, (0, 0, 29, 10)),
        ('go', 3, 19), ('go', 3, 17), ('mv', 'R L'), ('go', 3, 15),
        ('seq', 'U D5 L'),
        ('until', 5, 17, 'GEM', 400),
        ('collect', ALL),
        ('into', 24, 20)]),
    ('H', [
        ('go', 27, 4), ('collect', ALL), ('into', 19, 9),
        ('go', 14, 17), ('into', 14, 18), ('go', 26, 20),
        ('until', 27, 3, 'GEM', 4000), ('go', 27, 3),
        ('collect', ALL),
        ('into', 28, 19)]),
    ('J', [
        ('collect', ALL, (0, 0, 29, 1)),
        ('go', 6, 2), ('collect', ALL, (2, 3, 26, 7)),
        ('go', 2, 9), ('go', 2, 10), ('mv', 'R U R R R D'),
        ('until', 4, 14, 'MONSTER', 300), ('mv', 'L'), ('wait', 12),
        ('collect', ALL, (0, 9, 29, 21)),
        ('into', 15, 18),
        ('into', 27, 20)]),
    ('L', [
        ('go', 2, 2), ('go', 2, 3), ('mv', 'R U R R R D'),
        ('until', 4, 7, 'MONSTER', 300), ('mv', 'L'), ('wait', 12),
        ('go', 15, 4), ('mv', 'D D U'),
        ('until', 15, 10, 'MONSTER', 300), ('mv', 'U'), ('wait', 14),
        ('collect', ALL),
        ('into', 10, 17),
        ('into', 25, 20)]),
    ('P', [
        ('collect', ALL, (0, 0, 29, 7)),
        ('go', 2, 7), ('go', 2, 8), ('mv', 'R U R R R D'),
        ('until', 4, 12, 'MONSTER', 300), ('mv', 'L'), ('wait', 12),
        ('collect', ALL),
        ('into', 15, 16),
        ('into', 26, 16)]),
    ('A', [('into', 28, 20)]),
    ('G', [
        ('go', 4, 3), ('mv', 'R'), ('go', 3, 5), ('mv', 'R R L'), ('go', 7, 3),
        ('until', 5, 8, 'MONSTER', 300), ('mv', 'L'), ('wait', 12),
        ('go', 17, 3), ('mv', 'R'), ('go', 16, 5), ('mv', 'R R L'), ('go', 20, 3),
        ('until', 18, 8, 'MONSTER', 300), ('mv', 'L'), ('wait', 12),
        ('collect', ALL),
        ('go', 1, 16), ('go', 3, 17), ('mv', 'R2 . R6 . R6 .'), ('go', 26, 17), ('into', 27, 17),
        ('into', 28, 13)]),
    ('I', [
        ('collect', ALL, (0, 0, 29, 13)),
        ('go', 2, 14), ('go', 2, 15), ('mv', 'R U R R R D'),
        ('until', 4, 19, 'MONSTER', 300), ('mv', 'L'), ('wait', 12),
        ('collect', ALL),
        ('into', 28, 15)]),
    ('K', [
        ('go', 9, 2), ('go', 9, 3), ('mv', 'R'),
        ('go', 10, 0), ('go', 12, 0), ('go', 12, 2), ('go', 13, 2), ('go', 13, 3), ('mv', 'L'),
        ('go', 12, 2),
        ('until', 11, 7, 'MONSTER', 300), ('mv', 'L R'),
        ('wait', 12),
        ('go', 3, 13), ('mv', 'R12'), ('mv', 'R'), ('into', 17, 13)]),
    ('K', [
        ('collect', ALL),
        ('go', 1, 18), ('go', 3, 19), ('mv', 'R2 . R6 . R6 .'), ('go', 26, 19), ('into', 27, 19),
        ('collect', ALL),
        ('into', 28, 11)]),
    ('M', [
        ('go', 8, 5), ('go', 7, 5), ('mv', 'U D R'),
        ('until', 11, 3, 'GEM', 300), ('go', 11, 3),
        ('go', 24, 10), ('go', 24, 8), ('mv', 'R L'), ('go', 24, 6),
        ('seq', 'U D5 L'),
        ('until', 26, 8, 'GEM', 300),
        ('collect', ALL, (0, 0, 29, 10)),
        ('into', 2, 21), ('go', 29, 17),
        ('until', 28, 15, 'GEM', 3000), ('until', 14, 20, 'GEM', 3000),
        ('collect', ALL),
        ('into', 12, 10)]),
    ('P', [('collect', ALL), ('into', 26, 16)]),
    ('A', [('into', 27, 5)]),
    ('C', [('collect', ALL), ('into', 0, 0)]),
    ('A', [('into', 1, 20)]),
    ('F', [('collect', ALL), ('into', 0, 0)]),
    ('A', [('collect', ALL), ('into', 14, 12)]),
]
