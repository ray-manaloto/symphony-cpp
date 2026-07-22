# Implementation goal log

Append-only record for the standalone implementation.

| Date | Observation | Decision |
| --- | --- | --- |
| 2026-07-22 | A new repository avoids coupling the C++ service to the honeymoon Node controller. Both research lanes already have current artifacts. | Bootstrap a fixture-only C++ vertical slice; mark primary and Last30Days research `reused`; prohibit live mutations and publication. |
| 2026-07-22 | The initial portable Linux C++26 suite passed, then dependency-enabled Docker commands detached after the tool window and overlapping invocations corrupted Ninja's log. | Treat long compiler/build jobs as named containers and poll one owner; never start a duplicate for an unchanged running build. This is `promoted` into `scripts/container-job.sh`. |
