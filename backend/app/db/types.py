from sqlalchemy import BigInteger, Integer


# PostgreSQL では BIGINT、SQLite では INTEGER として扱う。
# SQLite の主キー自動採番を有効にするための型エイリアス。
DBInt = BigInteger().with_variant(Integer, "sqlite")
