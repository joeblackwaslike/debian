## Unreleased
Added a Debian 13 (trixie) image in `trixie/`.

* Built from a plain multi-stage Dockerfile with mmdebstrap and an explicit 19-package list. The fab and chanko toolchain is not used.
* Includes dumb-init 1.2.5 and gosu 1.20 (checksum-pinned, amd64 and arm64), openssl, and apt sources over https.
* 22.5MB compressed and 62MB on disk on arm64, against 30.2MB and 104MB for `debian:trixie-slim`.
* `trixie/test.sh` is the smoke test. goss, the container-utils scripts and the entrypoint.d layout are not ported.
* The jessie and stretch build in `base-repo/` is unchanged and does not run on trixie.

## 0.1.2
Huge refactor for entire build system.

* Moving most of the overall logic to the Makefile at the root of the repo.
* Made building releases other than jessie alot more flexible, just export `RELEASE=debian/<codename>` before running `make build`.
* Removed binaries from the repo, they are downloaded, verified, and packed in their own units now.
* Removed scripts and functions from the repo, into their own repo, which is downloaded and moved in the image build phase.
* Added [goss](https://github.com/aelsabbahy/goss) for building serverspec tests automatically.
* Refactored CI environment functions.
