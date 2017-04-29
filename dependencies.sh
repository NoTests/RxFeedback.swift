set -e
if [[ ( ! -d "RxSwift" ) && ( ! -d "Carthage" ) ]]; then
    git submodule update --init --recursive --force
fi
