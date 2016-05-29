# LoopKit

[![Build Status](https://travis-ci.org/loudnate/LoopKit.svg?branch=master)](https://travis-ci.org/loudnate/LoopKit)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Join the chat at https://gitter.im/loudnate/LoopKit](https://badges.gitter.im/loudnate/LoopKit.svg)](https://gitter.im/loudnate/LoopKit?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

LoopKit is a set of tools to speed up development of your own closed-loop insulin delivery app. It is agnostic to treatment decisions and input sources.

## Loop

[https://github.com/loudnate/Loop](Loop) is a full-featured app built on top of LoopKit.

## LoopKit provides

* Data storage and retrieval, using HealthKit and Core Data as appropriate
* Protocol types for representing data models in a flexible way
* Common calculation algorithms like Insulin On Board
* Boilerplate user interfaces like editing basal rate schedules and carb entry

## LoopKit does not provide

* Treatment decisions: Your Diabetes My Vary.
* Device communications: Device-specific libraries are maintained separately.

# License

LoopKit is available under the MIT license. See the LICENSE file for more info.

# Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](https://github.com/loudnate/LoopKit/blob/master/CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.
