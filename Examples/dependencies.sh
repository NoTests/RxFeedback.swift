set -e
if [[ ( ! -d "RxSwift/Rx.xcodeproj" ) ]]; then
    git submodule update --init --recursive --force
    cd RxSwift
    git reset origin/master --hard
    echo "We've downloaded missing git submodule. Please rebuild."
    exit -1
fi
