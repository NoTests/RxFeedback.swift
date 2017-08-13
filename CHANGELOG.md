## Master


## [0.3.0](https://github.com/kzaher/RxFeedback/releases/tag/0.3.0)

* Improves reentrancy properties.
* Adds `ObservableSchedulerContext` and additional `system` operator overload that enables passing of scheduler to feedback loops to improve cancellation guarantees.
* Improves built in feedback loops with additional cancellation guarantees.
    * Receiving stale events by using built-in feedback loops shouldn't be possible anymore.
* Deprecates feedback loops that don't use scheduler argument.