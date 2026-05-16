# Data Collection Strategy (Face)

## Muc tieu 3 nhan

- `owner`: mat khop voi chu nha da enroll
- `stranger`: co mat nhung khong khop owner
- `no_face`: khong phat hien mat

## Co can ve bounding box thu cong khong?

Khong. MVP dung detector co san de tim mat tu dong.

- Thu thap: luu anh goc JPG tu `/capture`
- Enroll: script tu detect face va encode
- Runtime: detector tim face box, embedding model danh gia owner/stranger

Bounding box chi dung noi bo trong pipeline, khong can gan nhan tay.

## Quy trinh thu thap owner

1. Chuan bi:
   - Dat camera o vi tri giong thuc te mo cua
   - Bat den ban ngay + ban dem (2 dieu kien sang)
2. Capture raw:
   - Dung script `capture_owner_dataset.py` de lay ~60 anh
   - Khoang cach da dang: 0.5m, 1m, 1.5m
   - Goc mat: thang, lech trai/phai, ngua/xuoi nhe
3. Loc chat luong:
   - Chi giu frame co dung 1 mat
   - Mat du lon (`min-face-size`)
   - Khong nhoe (`min-blur-score`)
   - Do sang hop ly (`min/max brightness`)
4. Tao embedding:
   - Chay `enroll_owner.py`
   - Neu anh loi (khong mat/nhieu mat), script tu reject

## Stranger va no_face co can dataset rieng?

- `stranger`: khong can train rieng. Moi mat khong khop owner => stranger.
- `no_face`: do detector tra ve 0 face.

Co the thu them 20-30 anh nguoi la de tune threshold va cooldown canh bao.

## Model dung trong MVP

- Face embedding: `face_recognition` (dlib, vector 128-D)
- So khop: Euclidean distance + threshold (`FACE_MATCH_THRESHOLD`, mac dinh 0.5)
- Gan nhan `owner` chi khi confidence > `FACE_OWNER_CONFIDENCE_THRESHOLD` (mac dinh 0.6)
- Detector:
  - `hog` (nhe, hop laptop CPU)
  - `cnn` (chinh xac hon, nen co GPU)
