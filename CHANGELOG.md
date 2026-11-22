# Changelog

## [4.1.0](https://github.com/state-machines/state_machines-audit_trail/compare/state_machines-audit_trail/v4.0.0...state_machines-audit_trail/v4.1.0) (2026-11-22)


### Features

* **audit_trail:** make transition columns optional ([#56](https://github.com/state-machines/state_machines-audit_trail/issues/56)) ([96aa661](https://github.com/state-machines/state_machines-audit_trail/commit/96aa6615eec0ff21338984b5fc840ec48bdc7e13))


### Bug Fixes

* **audit_trail:** fail saves on :context errors ([#55](https://github.com/state-machines/state_machines-audit_trail/issues/55)) ([555d788](https://github.com/state-machines/state_machines-audit_trail/commit/555d788bf42d3db542914515043e2aecf7413eb6)), closes [#53](https://github.com/state-machines/state_machines-audit_trail/issues/53)

## [4.0.0](https://github.com/state-machines/state_machines-audit_trail/compare/state_machines-audit_trail/v3.0.0...state_machines-audit_trail/v4.0.0) (2026-11-17)


### ⚠ BREAKING CHANGES

* Rails appraisal support now starts at Rails 8.0.

### Features

* drop Rails 7 support ([ce4607d](https://github.com/state-machines/state_machines-audit_trail/commit/ce4607dc3c2f056e9a9a258f20e217755b77ffda))
* move to minitest ([#48](https://github.com/state-machines/state_machines-audit_trail/issues/48)) ([7ef8785](https://github.com/state-machines/state_machines-audit_trail/commit/7ef8785ec05b21f519a46e26faee2280480e46e6))


### Bug Fixes

* **active_record:** raise when an audit record cannot be written ([e4493e3](https://github.com/state-machines/state_machines-audit_trail/commit/e4493e350dab01b5499535f33bb067119f5f69f4))
* **audit_trail:** a save owes rows only through the journal ([6768a1b](https://github.com/state-machines/state_machines-audit_trail/commit/6768a1b9dc6c9a24eaabf5721a9bacd110c352fc))
* **audit_trail:** find the journal on Rails main's attribute sets ([5aee0dc](https://github.com/state-machines/state_machines-audit_trail/commit/5aee0dced33d7b5bf9ce2e418c979f28c7729b6c))
* **audit_trail:** follow running transitions across reloads, write only what the row holds ([fcaed1e](https://github.com/state-machines/state_machines-audit_trail/commit/fcaed1ecac0a91b973cbee09a751c6c3c3bd13ee))
* **audit_trail:** keep one ordered journal per record and fail saves loudly ([4b427b8](https://github.com/state-machines/state_machines-audit_trail/commit/4b427b84201709a3645771076d40c8f0f36ba731))
* **audit_trail:** keep rows of open transactions across a reload ([b7712eb](https://github.com/state-machines/state_machines-audit_trail/commit/b7712ebc6753d004ac4a8cb24e935a9941538bbb))
* **audit_trail:** keep rows pending until the outermost commit ([ce25e89](https://github.com/state-machines/state_machines-audit_trail/commit/ce25e89ef816915d508ff1b942ae2b781500943b))
* **audit_trail:** keep the journal on the record's attribute set ([18b0a98](https://github.com/state-machines/state_machines-audit_trail/commit/18b0a98101ffcd9cc309150b8838e064e710b442))
* **audit_trail:** keep the journal through a rolled back destroy ([3ae8064](https://github.com/state-machines/state_machines-audit_trail/commit/3ae80640a33ed8d5d80383d8c95a38f5f5b59a04))
* **audit_trail:** log the initial transition once across retried creates ([3b71b7a](https://github.com/state-machines/state_machines-audit_trail/commit/3b71b7aeb85b08b51c0e74c6b6b5c2e321c18edf))
* **audit_trail:** prepend a copy of the record hooks per class ([59ffddf](https://github.com/state-machines/state_machines-audit_trail/commit/59ffddf9f8031efbc4da36629639cc8bc8c72ebe))
* **audit_trail:** record transitions whose state change is in place ([3968a43](https://github.com/state-machines/state_machines-audit_trail/commit/3968a43f84aee3d5ed63451147e93679f1df60f0))
* **audit_trail:** tie the journal to the record's attributes and bound it ([99c4bca](https://github.com/state-machines/state_machines-audit_trail/commit/99c4bcaa56d4cc172a6ee96675aa4d68dd908134))
* **audit_trail:** track what each save writes per save, across reloads and nesting ([c771496](https://github.com/state-machines/state_machines-audit_trail/commit/c7714960e6b5dcdce264a365b2025bc3c8e10c68))
* **audit_trail:** write each audit when its transition commits ([ddcc566](https://github.com/state-machines/state_machines-audit_trail/commit/ddcc566c305671385f79d69561f55e56565f03d4))
* **deps:** require state_machines and state_machines-activerecord 0.304.0 ([7d3ea78](https://github.com/state-machines/state_machines-audit_trail/commit/7d3ea78f8922b36f538cf125238ce6db011509b8))
* **rake:** run rubocop in the default task ([01f20fa](https://github.com/state-machines/state_machines-audit_trail/commit/01f20fafc5be49fa06f8d85588db1ea5b051b192))
* resolve audit_trail context at save time, not at .new time ([#23](https://github.com/state-machines/state_machines-audit_trail/issues/23)) ([ab6f99e](https://github.com/state-machines/state_machines-audit_trail/commit/ab6f99e1b9164a444393f860657568584160707d))

## [3.0.0](https://github.com/state-machines/state_machines-audit_trail/compare/state_machines-audit_trail/v2.1.0...state_machines-audit_trail/v3.0.0) (2025-06-12)


### Bug Fixes

* normalize release please ([8f2a44b](https://github.com/state-machines/state_machines-audit_trail/commit/8f2a44bb2fbb44d51533cce7665286bccad89136))

## [2.1.0](https://github.com/state-machines/state_machines-audit_trail/compare/state_machines-audit_trail-v2.0.2...state_machines-audit_trail/v2.1.0) (2024-01-22)

### Features

* Eliminate usage of OpenStruct ([7cac29f](https://github.com/state-machines/state_machines-audit_trail/commit/7cac29f0dceb5e7a39c8ea81787c535159432466))


### Bug Fixes

* trigger build ([24a92e9](https://github.com/state-machines/state_machines-audit_trail/commit/24a92e92ef6a16d53e4b858097c8bae163eb696b))
