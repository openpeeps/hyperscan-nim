<p align="center">
  Nim bindings for Intel's Hyperscan<br>
  Regex matching library
</p>

<p align="center">
  <code>nimble install hyperscan</code>
</p>

<p align="center">
  <a href="https://openpeeps.github.io/hyperscan">API reference</a><br>
  <img src="https://github.com/openpeeps/hyperscan/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/openpeeps/hyperscan/workflows/docs/badge.svg" alt="Github Actions">
</p>

## About Intel's Hyperscan
Hyperscan is a high-performance regular expression matching library capable of scanning data at high speeds. It is used as a critical engine within network security, and Deep Packet Inspection (DPI) applications to search for large sets of patterns simultaneously across streaming data. [Readh the Introduction to Hyperscan](https://www.intel.com/content/www/us/en/developer/articles/technical/introduction-to-hyperscan.html)

Check out the [official repository](https://github.com/intel/hyperscan)

This Nim package provides:
- Low-level C-style bindings to the Hyperscan library
- A high-level, idiomatic Nim API for easier usage

## Examples

Here is an example using the high-level API:
```nim
import hyperscan

# Compile a pattern into a database
let db = compile("foo", HS_FLAG_CASELESS)

# Scan some data
let data = "Hello foo world"
discard db.scan(data) do (id: cuint, fromOffset, toOffset: culonglong) -> bool:
  echo "Match found! ID: ", id, " From: ", fromOffset, " To: ", toOffset
  return true  # Continue scanning

# Serialize the database
let serializedDb = db.serialize()
echo "Serialized database size: ", serializedDb.len

# Deserialize the database
let db2 = deserialize(serializedDb)

# Scan again with the deserialized database
discard db2.scan(data) do (id: cuint, fromOffset, toOffset: culonglong) -> bool:
  echo "Match found in deserialized DB! ID: ", id, " From: ", fromOffset, " To: ", toOffset
  return true
```

Here is an example using the low-level API to compile a pattern, scan some data, and handle matches:
```nim
import hyperscan/bindings

# Define a match event handler
proc onMatch(id: cuint, fromOffset, toOffset: culonglong, flags: cuint, context: pointer): cint {.cdecl.} =
  echo "Match found! ID: ", id, " From: ", fromOffset, " To: ", toOffset
  return 0

# Compile a pattern
var db: HsDatabasePtr = nil
var err: HsCompileErrorPtr = nil
let pattern = "foo"
let compileResult = hs_compile(pattern, HS_FLAG_CASELESS, HS_MODE_BLOCK, nil, addr db, addr err)

if compileResult == HS_SUCCESS:
  echo "Pattern compiled successfully!"
else:
  echo "Failed to compile pattern: ", err.message
  quit(1)

# Allocate scratch space
var scratch: HsScratchPtr = nil
let scratchResult = hs_alloc_scratch(db, addr scratch)

if scratchResult != HS_SUCCESS:
  echo "Failed to allocate scratch space!"
  discard hs_free_database(db)
  quit(1)

# Scan data
let data = "Hello foo world"
let scanResult = hs_scan(db, data, cuint(len(data)), 0.cuint, scratch, onMatch, nil)

if scanResult == HS_SUCCESS:
  echo "Scan completed successfully!"
else:
  echo "Scan failed!"

# Clean up
discard hs_free_scratch(scratch)
discard hs_free_database(db)
```

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/openpeeps/hyperscan/issues)
- 👋 Wanna help? [Fork it!](https://github.com/openpeeps/hyperscan/fork)
- 😎 [Get €20 in cloud credits from Hetzner](https://hetzner.cloud/?ref=Hm0mYGM9NxZ4)

### 🎩 License
MIT license. [Made by Humans from OpenPeeps](https://github.com/openpeeps).<br>
Copyright OpenPeeps & Contributors &mdash; All rights reserved.
