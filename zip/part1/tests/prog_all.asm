# TEST ALL: every supported instruction, each result is stored to memory
# (results are only observable through sw)
# ---- addi (positive and negative immediates) ----
addi $1, $0, 12       # $1 = 12
addi $2, $0, 5        # $2 = 5
addi $3, $0, -3       # $3 = -3
# ---- R-type ALU ----
add  $4, $1, $2       # 12 + 5  = 17
sub  $5, $1, $2       # 12 - 5  = 7
and  $6, $1, $2       # 1100 & 0101 = 4
or   $7, $1, $2       # 1100 | 0101 = 13
slt  $8, $2, $1       # 5 < 12        -> 1
slt  $9, $1, $2       # 12 < 5        -> 0
slt  $10, $3, $2      # -3 < 5 signed -> 1
sub  $11, $3, $1      # -3 - 12 = -15
# ---- sw: store every result (back-to-back stores) ----
sw   $4, 0($0)
sw   $5, 4($0)
sw   $6, 8($0)
sw   $7, 12($0)
sw   $8, 16($0)
sw   $9, 20($0)
sw   $10, 24($0)
sw   $11, 28($0)
sw   $3, 32($0)
# ---- lw: read back, use the loaded values, store with a base register ----
lw   $12, 4($0)       # $12 = 7
lw   $13, 28($0)      # $13 = -15
add  $14, $12, $13    # 7 + (-15) = -8
sw   $14, 36($0)
sw   $13, 40($1)      # base + offset: 12 + 40 = 52
lw   $15, 40($1)      # $15 = -15
sw   $15, 44($0)
# ---- beq not taken: the store after it MUST happen ----
beq  $1, $2, skip1    # 12 != 5
sw   $2, 48($0)
skip1:
# ---- beq taken: the store after it must NOT happen ----
beq  $12, $5, skip2   # 7 == 7
sw   $1, 56($0)       # wrong path
skip2:
sw   $5, 60($0)
# ---- j: the store after it must NOT happen ----
j    done
sw   $1, 64($0)       # wrong path
done:
sw   $7, 68($0)
