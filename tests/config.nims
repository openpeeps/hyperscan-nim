switch("path", "$projectDir/../src")

when defined(macosx):
  --passC:"-I/opt/local/include"
  --passL:"-L/opt/local/lib -lhs"
elif defined(linux):
  --passC:"-I/usr/local/include"
  --passL:"-L/usr/local/lib -lhs"