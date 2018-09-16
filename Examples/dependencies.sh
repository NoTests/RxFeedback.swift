set -e
if [[ ( ! -d "RxSwift/Rx.xcodeproj" ) ]]; then
    git submodule update --init --recursive --force
    cd RxSwift
    git reset origin/master --hard
    osascript -e 'tell app "Xcode" to display dialog "We have automatically downloaded git submodules for you and you need to reopen the project so Xcode can detect submodule change properly."'
    killall Xcode
fi
