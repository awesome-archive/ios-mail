| ⚠️ The `master` branch has been discontinued. For the latest Proton Mail codebase please check the `main` branch ⚠️ |
| --- |

# iOS-mail

## Introduction

iOS-mail — ProtonMail iOS client app

The app is intended for all users of the ProtonMail service. Whether they are paid or free, they can compose and read emails, manage folders and labels, manage some account settings and create a new account. The app supports iOS versions 11 and above.

## License

The code and data files in this distribution are licensed under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. See <https://www.gnu.org/licenses/> for a copy of this license.

See [LICENSE](LICENSE) file

## Table of Contents

<!-- TOC depthFrom:3 -->
- [Introduction](#Introduction)
- [License](#License)
- [Architecture](#Architecture)
- [Dependencies](#Dependencies)
    - [Internal](#Internal)
    - [Third Party](#Third-Party)
- [Content Explanation](#Content-Explanation)
- [Setup](#setup)
- [Live version](#live-version)
- [Articles](#Articles)
- [Our Team](#our-team)
- [TODO](#todo)
<!-- /TOC -->

## Architecture

[MVVM-C](mvvmc.png) with services. Model-View-ViewModel architecture, plus the Coordinator pattern.

## Dependencies

### Internal

- [gopenpgp](https://github.com/ProtonMail/gopenpgp)
- [OpenPGP](https://github.com/ProtonMail/cpp-openpgp)
- [VCard](https://github.com/ProtonMail/cpp-openpgp)
- [go-srp](https://github.com/ProtonMail/go-srp)

### Third Party

[Acknowledgements](Acknowledgements.md)

## Content Explanation

<!-- TOC depthFrom:3 -->
- [OpenPGP](OpenPGP/README.md)
- [Keymaker](ProtonMail/Keymaker/README.md)
- [ProtonMail](ProtonMail/ProtonMail/README.md)
- [PushService](ProtonMail/PushService/README.md)
- [Share](ProtonMail/Share/README.md)
- [Siri](ProtonMail/Siri/README.md)
- [Scripts](Scripts/README.md)
- [Trust Model](ProtonMail/README.md#Trust-Model)
- [Local Data Protection](ProtonMail/README.md#Local-Data)
<!-- /TOC -->

## Setup

1. Have macOS up to date and install Xcode 14 +
2. We are using [Mint](https://github.com/yonaskolb/mint) as our package manager, If you don't have it, you can install it via [Homebrew](https://brew.sh/) by `brew bundle --file="ProtonMail/Brewfile" --no-upgrade` then run `mint bootstrap` to install dependecies
3. [DOMPurify](https://github.com/cure53/DOMPurify) and Cocoapods are pre-downloaded. We are using git submodules for tracking DOMPurifier, so after cloning you have to run `git submodule init` and `git submodule update` to fetch it. Theory here: https://git-scm.com/book/en/v2/Git-Tools-Submodules
4. We are using [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate Xcode project, `sh ProtonMail/xcodeGenHelper.sh`
5. Open `ProtonMail/ProtonMail.xcworkspace` and update project settings to use your own provisioning profile.
6. Run the app.

## Live version

Current live version 4.2.2

- [Apple Store](https://apps.apple.com/app/protonmail-encrypted-email/id979659905)

## Articles

- [Open sourcing](https://proton.me/blog/ios-open-source)
- [Security model](https://proton.me/blog/ios-security-model)

## Our Team

- [Anson](https://github.com/xxi511)
- [Mustapha](https://github.com/justarandomdev)
- [Steven](https://github.com/Linquas)
- [Jacek](https://github.com/jacekkra)
- [Xavi](https://github.com/xavigil)
