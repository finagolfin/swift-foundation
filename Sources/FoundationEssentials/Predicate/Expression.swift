//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public protocol PredicateExpression<Output> {
    associatedtype Output
    
    func evaluate(_ bindings: PredicateBindings) throws -> Output
}

// Only Foundation should add conformances to this protocol
@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public protocol StandardPredicateExpression<Output> : PredicateExpression, Codable, Sendable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
public struct PredicateError: Error, Hashable, CustomDebugStringConvertible {
    internal enum _Error: Hashable, Sendable {
        case undefinedVariable
        case forceUnwrapFailure(String?)
        case forceCastFailure(String?)
    }
    
    private let _error: _Error
    
    internal init(_ error: _Error) {
        _error = error
    }
    
    public var debugDescription: String {
        switch _error {
        case .undefinedVariable:
            return "Encountered an undefined variable"
        case .forceUnwrapFailure(let string):
            return string ?? "Attempted to force unwrap a nil value"
        case .forceCastFailure(let string):
            return string ?? "Failed to cast a value to the desired type"
        }
    }
    
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch lhs._error {
        case .undefinedVariable:
            return rhs == .undefinedVariable
        case .forceCastFailure(_):
            if case .forceCastFailure(_) = rhs._error {
                return true
            }
            return false
        case .forceUnwrapFailure(_):
            if case .forceUnwrapFailure(_) = rhs._error {
                return true
            }
            return false
        }
    }
    
    public static let undefinedVariable = Self(.undefinedVariable)
    public static let forceUnwrapFailure = Self(.forceUnwrapFailure(nil))
    public static let forceCastFailure = Self(.forceCastFailure(nil))
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions {
    public struct VariableID: Hashable, Codable, Sendable {
        let id: UInt
        private static let nextID = LockedState(initialState: UInt(0))
        
        fileprivate init() {
            self.id = Self.nextID.withLock { value in
                defer {
                    (value, _) = value.addingReportingOverflow(1)
                }
                return value
            }
        }
    }
    
    public struct Variable<Output> : StandardPredicateExpression {
        public let key: VariableID
        
        public init() {
            self.key = VariableID()
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            if let value = bindings[self] {
                return value
            }
            throw PredicateError.undefinedVariable
        }
    }
    
    public struct KeyPath<Root : PredicateExpression, Output> : PredicateExpression {
        public let root: Root
        public let keyPath: Swift.KeyPath<Root.Output, Output> & Sendable
        
        public init(root: Root, keyPath: Swift.KeyPath<Root.Output, Output> & Sendable) {
            self.root = root
            self.keyPath = keyPath
        }
        
        public func evaluate(_ bindings: PredicateBindings) throws -> Output {
            return try root.evaluate(bindings)[keyPath: keyPath as Swift.KeyPath<Root.Output, Output>]
        }
    }

    public struct Value<Output> : PredicateExpression {
        public let value: Output
        
        public init(_ value: Output) {
            self.value = value
        }
        
        public func evaluate(_ bindings: PredicateBindings) -> Output {
            return self.value
        }
    }
    
    public static func build_Arg<T>(_ arg: T) -> Value<T> {
        Value(arg)
    }
    
    public static func build_Arg<T: PredicateExpression>(_ arg: T) -> T {
        arg
    }
    
    public static func build_KeyPath<Root, Value>(root: Root, keyPath: Swift.KeyPath<Root.Output, Value>) -> PredicateExpressions.KeyPath<Root, Value> {
        KeyPath(root: root, keyPath: keyPath)
    }

}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.KeyPath : Codable where Root : Codable {
    private enum CodingKeys: String, CodingKey {
        case root
        case keyPath
    }
    
    public init(from decoder: Decoder) throws {
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Decoding a PredicateExpressions.KeyPath is not currently supported"))
    }
    
    public func encode(to encoder: Encoder) throws {
        throw EncodingError.invalidValue(self, .init(codingPath: encoder.codingPath, debugDescription: "Encoding a PredicateExpressions.KeyPath is not currently supported"))
    }
}
@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.KeyPath : Sendable where Root : Sendable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.KeyPath : StandardPredicateExpression where Root : StandardPredicateExpression {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.Value : Codable where Output : Codable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.Value : Sendable where Output : Sendable {}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
extension PredicateExpressions.Value : StandardPredicateExpression where Output : Codable /*, Output : Sendable*/ {}
