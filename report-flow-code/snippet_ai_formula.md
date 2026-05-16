# AI formula notes for report

Khoang cach Euclid giua embedding moi x va embedding mau e_i:

`d_i = ||x - e_i||_2 = sqrt(sum_j (x_j - e_ij)^2 )`

Khoang cach dai dien:

`d_min = min_i d_i`

Diem tin cay noi bo:

`confidence = clip(1 - d_min, 0, 1)`

Quy tac gan nhan:

- owner neu `d_min <= FACE_MATCH_THRESHOLD` va `confidence > FACE_OWNER_CONFIDENCE_THRESHOLD`
- stranger neu co mat nhung khong dat dieu kien owner
- no_face neu khong phat hien mat
