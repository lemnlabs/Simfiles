![Light](docs/images/banner/light.png#gh-light-mode-only)
![Dark](docs/images/banner/dark.png#gh-dark-mode-only)

# Simfiles

[English](README.md) | [한국어](README.ko.md)

> Xcode 시뮬레이터 환경과 앱 샌드박스 파일 시스템(`Documents`, `Library`, `tmp` 등)을 실시간으로 탐색하고 제어하는 네이티브 macOS 유틸리티

[![Platform](https://img.shields.io/badge/Platform-macOS%2015.0%2B-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-16.0%2B-blue.svg)](https://developer.apple.com/xcode/)
[![Homebrew](https://img.shields.io/badge/Homebrew-lemnlabs%2Ftap-blue.svg)](https://github.com/lemnlabs/homebrew-tap)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Active%20Development-yellow.svg)](https://github.com/lemnlabs/Simfiles)

---

## Preview

<p align="center">
    <img alt="Preview" src="docs/images/screenshot.png">
</p>

---

## Features

### 시뮬레이터 기기 관리
- **통합 기기 탐색**: iOS, iPadOS, watchOS, tvOS, visionOS 등 설치된 모든 시뮬레이터를 OS 런타임 버전별로 그룹화하여 탐색합니다.
- **라이프사이클 제어**: 사이드바에서 시뮬레이터 부팅(Boot), 종료(Shutdown), 부팅된 기기 필터링 및 네이티브 `Simulator.app` 바로 실행을 지원합니다.
- **미디어 파일 주입**: 원클릭으로 시뮬레이터 사진 보관함에 사진 및 동영상을 추가합니다 (`xcrun simctl addmedia`).
- **빠른 식별자 및 경로 복사**: 기기 UDID 복사, Finder에서 시뮬레이터 데이터 폴더 및 미디어 폴더 열기를 지원합니다.

### 설치된 애플리케이션 탐색
- **앱 목록 및 필터링**: 사용자 설치 앱과 기본 시스템 앱을 즉시 전환하여 확인하고, 이름 또는 번들 ID로 실시간 검색할 수 있습니다.
- **프로세스 감지 및 제어**: 부팅된 시뮬레이터에서 앱 실행(Running) 여부를 감지하고, 원클릭으로 앱을 실행하거나 강제 종료합니다.
- **컨테이너 바로가기**: 앱 번들(`.app`) 및 데이터 컨테이너 폴더를 Finder에서 바로 열 수 있습니다.

### 샌드박스 파일 브라우저
- **표준 샌드박스 디렉터리 이동**: `Documents`, `Library`, `tmp`, `Root` 컨테이너 디렉터리를 간편하게 전환합니다.
- **Finder 스타일 테이블 뷰**: 이름, 종류, 크기, 수정일 정렬을 지원하며 폴더 상단 고정 옵션을 제공합니다.
- **드래그 앤 드롭 가져오기**: macOS Finder에서 파일 및 폴더를 드래그하여 앱 샌드박스로 즉시 가져옵니다.
- **완전한 파일 조작**: 폴더 생성, 이름 변경, 복사, 잘라내기, 붙여넣기 및 macOS 휴지통으로의 안전한 삭제를 지원합니다.
- **Quick Look 및 도구 연동**: 스페이스바(`Space`)로 Quick Look(훑어보기) 미리보기를 지원하며, macOS Terminal 및 Finder에서 바로 열 수 있습니다.
- **실시간 파일 시스템 동기화**: 저수준 파일 시스템 모니터링(`DispatchSource`)을 통해 앱 내부나 외부에서 발생한 파일 변경 사항을 새로고침 없이 즉각 반영합니다.

---

## Requirements

### 사용자 요구사항 (End User)
- **운영체제**: macOS 15.0 (Sequoia) 이상
- **아키텍처**: Apple Silicon (M1/M2/M3/M4) 및 Intel Mac (Universal 바이너리 지원)
- **필수 도구**: Xcode 16.0 이상 및 Command Line Tools (`xcrun simctl`)

### 개발 환경 요구사항 (Developer)
- **Xcode**: Xcode 16.0 이상
- **Swift**: Swift 6.0 툴체인 (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
- **코드 품질**: `swift-format` (코드 린트 및 스타일 포맷팅)

---

## Installation

### 방법 1: Homebrew Cask (권장)
[lemnlabs/homebrew-tap](https://github.com/lemnlabs/homebrew-tap) 저장소를 통해 터미널에서 한 줄로 간편하게 설치할 수 있습니다:

```bash
brew install --cask lemnlabs/tap/simfiles
```

추후 최신 버전으로 업데이트할 때:
```bash
brew upgrade --cask simfiles
```

### 방법 2: GitHub Releases 직접 다운로드
1. [GitHub Releases](https://github.com/lemnlabs/Simfiles/releases)에서 최신 버전의 `Simfiles.dmg` 또는 `Simfiles.zip`을 다운로드합니다.
2. `Simfiles.app`을 `/Applications` 폴더로 드래그합니다.

> [!IMPORTANT]
> 오픈소스 개발 빌드는 Apple Developer 인증서로 서명/공증(Notarized)되지 않은 상태일 수 있습니다. 최초 실행 시 Gatekeeper 보안 경고가 표시되는 경우:
> 1. **시스템 설정 > 개인정보 보호 및 보안**으로 이동합니다.
> 2. **보안** 섹션에서 **'확인 없이 열기'**를 클릭하여 실행합니다.
> *(Gatekeeper를 우회하기 위해 임의의 터미널 명령어(예: `xattr -cr`)를 사용하는 것은 권장하지 않습니다.)*

### 방법 3: 소스코드에서 직접 빌드하여 설치
저장소를 클론한 후 Release 빌드를 로컬에서 생성할 수 있습니다:

```bash
# 1. 저장소 클론
git clone https://github.com/lemnlabs/Simfiles.git
cd Simfiles

# 2. Release 빌드 실행
xcodebuild build -scheme Simfiles -destination 'platform=macOS' -configuration Release CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

# 3. 빌드된 앱 응용 프로그램 폴더로 복사
cp -R ~/Library/Developer/Xcode/DerivedData/Simfiles-*/Build/Products/Release/Simfiles.app /Applications/
```

---

## Usage

1. **시뮬레이터 선택**: 좌측 사이드바에서 디버깅할 시뮬레이터를 선택합니다. 종료 상태인 경우 부팅 버튼을 눌러 기기를 실행합니다.
2. **앱 선택**: 가운데 패널에서 대상 앱을 선택합니다. 상단 세그먼트 컨트롤로 사용자 설치 앱만 필터링하거나 번들 ID로 검색할 수 있습니다.
3. **샌드박스 파일 확인**: 우측 파일 브라우저에서 `Documents`, `Library`, `tmp` 등의 디렉터리를 탐색합니다.
4. **파일 가져오기 및 조작**: Finder에서 파일을 드래그하여 앱 창에 놓거나, 툴바 액션을 이용해 폴더 생성, 훑어보기, Finder에서 보기 등의 작업을 수행합니다.

### 주요 단축키
| 단축키 | 동작 |
| :--- | :--- |
| `Space` | 선택한 파일 Quick Look(훑어보기) 미리보기 |
| `Cmd + [` | 이전 폴더로 뒤로 이동 |
| `Cmd + ]` | 다음 폴더로 앞으로 이동 |
| `Cmd + Up` | 상위 폴더로 이동 |
| `Delete` 또는 `Cmd + Backspace` | 선택한 항목 휴지통으로 이동 (확인 다이얼로그 표시) |

---

## Privacy & Permissions

### 100% 로컬 처리 (원격 분석 및 네트워크 통신 없음)
- Simfiles는 **어떠한 네트워크 요청도 수행하지 않습니다**.
- 원격 서버 통신, 트래킹, 텔레메트리, 사용자 분석(Analytics) 코드가 전혀 없으며, 모든 파일 조작과 시뮬레이터 제어는 사용자의 Mac 로컬 환경 내에서만 안전하게 실행됩니다.

### 앱 샌드박스 비활성화 (Non-Sandboxed Utility) 사유
- Simfiles는 Xcode CoreSimulator의 컨테이너 경로(`~/Library/Developer/CoreSimulator/Devices/`)에 직접 접근하고 `xcrun simctl` 명령을 실행해야 합니다.
- macOS App Sandbox 정책상 기본 사용자 컨테이너 외부 경로에 대한 자유로운 파일 I/O 및 외부 CLI 하위 프로세스 호출이 엄격히 차단되므로, 의도적으로 App Sandbox를 비활성화(`ENABLE_APP_SANDBOX = NO`)하고 빌드됩니다.

### 시스템 권한 및 CLI 도구
- **파일 시스템 접근 권한**: 로컬 CoreSimulator 기기 디렉터리 내 파일 읽기, 쓰기 및 삭제
- **`xcrun simctl`**: 로컬 시뮬레이터 메타데이터 조회, 기기 부팅/종료, 미디어 자산 주입

---

## Development

저장소를 클론한 후 다음 명령어를 통해 로컬 빌드를 검증할 수 있습니다:

```bash
# 1. 저장소 클론
git clone https://github.com/lemnlabs/Simfiles.git
cd Simfiles

# 2. Xcode에서 프로젝트 열기
open Simfiles.xcodeproj

# 3. CLI를 통한 빌드 검증
xcodebuild build -scheme Simfiles -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

# 4. 코드 스타일 린트 및 자동 포맷팅
swift format lint -r Simfiles
swift format format -i -r Simfiles
```

- **아키텍처 상세**: MVVM 계층 설계 및 Swift 6 동시성 모델은 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)를 참고하세요.
- **개발 가이드**: 로컬 환경 구성 및 Xcode 16 파일 동기화 그룹 팁은 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)를 참고하세요.

---

## Contributing

버그 제보, 기능 개선 제안, 코드 기여를 환영합니다! 기여 절차 및 커밋 컨벤션은 [CONTRIBUTING.md](CONTRIBUTING.md)를 확인해 주세요.

---

## License

이 프로젝트는 [MIT License](LICENSE)에 따라 배포됩니다.
