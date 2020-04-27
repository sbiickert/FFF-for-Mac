//
//  CoreExtensions.swift
//  FFF ∞
//
//  Created by Simon Biickert on 2019-10-18.
//  Copyright © 2019 ii Softwerks. All rights reserved.
//

import Foundation

//extension Optional where Wrapped == String {
//    var _bound: String? {
//        get {
//            return self
//        }
//        set {
//            self = newValue
//        }
//    }
//    public var bound: String {
//        get {
//            return _bound ?? ""
//        }
//        set {
//            _bound = newValue.isEmpty ? nil : newValue
//        }
//    }
//}

extension Date {
    func interval(ofComponent comp: Calendar.Component, fromDate date: Date) -> Int {

        let currentCalendar = Calendar.current

        guard let start = currentCalendar.ordinality(of: comp, in: .era, for: date) else { return 0 }
        guard let end = currentCalendar.ordinality(of: comp, in: .era, for: self) else { return 0 }

        return end - start
    }
}
