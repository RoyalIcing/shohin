//
//  Elements.swift
//  Shohin
//
//  Created by Patrick Smith on 15/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import UIKit


public class ChangeApplier<Root> {
	private var applier: (Root) -> ()
	
	init(applier: @escaping (Root) -> ()) {
		self.applier = applier
	}
	
	public convenience init<Value>(_ keyPath: ReferenceWritableKeyPath<Root, Value>, value: Value) {
		self.init(applier: { root in
			root[keyPath: keyPath] = value
		})
	}
	
	public func apply(to root: Root) {
		applier(root)
	}
}

extension ChangeApplier where Root : AnyObject {
	public convenience init(makeChanges: @escaping (Root) -> ()) {
		self.init(applier: makeChanges)
	}
}


protocol ViewProps {
	associatedtype View : UIView
	
	static func set<Value>(_ keyPath: ReferenceWritableKeyPath<View, Value>, to value: Value) -> Self
}

extension ViewProps {
	public static func tag(_ tag: Int) -> Self {
		return self.set(\.tag, to: tag)
	}
}


public enum LabelProps<Msg> : ViewProps {
	typealias View = UILabel
	
	case text(String)
	case textAlignment(NSTextAlignment)
	case applyChange(ChangeApplier<UILabel>)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<UILabel, Value>, to value: Value) -> LabelProps {
		return .applyChange(ChangeApplier(keyPath, value: value))
	}
	
	fileprivate func apply(to label: UILabel, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		switch self {
		case let .text(text):
			label.text = text
		case let .textAlignment(alignment):
			label.textAlignment = alignment
		case let .applyChange(applier):
			applier.apply(to: label)
		}
	}
}

struct LabelElement<Msg> {
	let key: String
	let props: [LabelProps<Msg>]
	
	private var defaultLabel: UILabel {
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}
	
	func prepare(existing: UIView?) -> UIView {
		return existing as? UILabel ?? defaultLabel
	}
	
	private func applyToView(_ view: UIView, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		guard let label = view as? UILabel else { return }
		
		props.forEach { $0.apply(to: label, registerEventHandler: registerEventHandler) }
	}
	
	func toElement() -> Element<Msg> {
		return Element(key: key, makeViewIfNeeded: prepare, applyToView: applyToView)
	}
}

public func label<Key: RawRepresentable, Msg>(_ key: Key, _ props: [LabelProps<Msg>]) -> Element<Msg> where Key.RawValue == String {
	return LabelElement(key: key.rawValue, props: props).toElement()
}


public enum FieldProps<Msg> : ViewProps {
	typealias View = UITextField
	
	case text(String)
	case textAlignment(NSTextAlignment)
	case placeholder(String?)
	case keyboardType(UIKeyboardType)
	case returnKeyType(UIReturnKeyType)
	case applyChange(ChangeApplier<UITextField>)
	case on(UIControlEvents, toMessage: ((UITextField, UIEvent) -> Msg)?)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<UITextField, Value>, to value: Value) -> FieldProps {
		return .applyChange(ChangeApplier(keyPath, value: value))
	}
	
	fileprivate func apply(to field: UITextField, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		switch self {
		case let .text(text):
			field.text = text
		case let .textAlignment(alignment):
			field.textAlignment = alignment
		case let .placeholder(text):
			field.placeholder = text
		case let .keyboardType(keyboardType):
			field.keyboardType = keyboardType
		case let .returnKeyType(returnKeyType):
			field.returnKeyType = returnKeyType
		case let .applyChange(applier):
			applier.apply(to: field)
		case let .on(controlEvents, toMessage):
			let key = String(describing: controlEvents)
			let (target, action) = registerEventHandler(key, toMessage.map { MessageMaker(control: $0) } ?? MessageMaker(), EventHandlingOptions())
			field.addTarget(target, action: action, for: controlEvents)
		}
	}
}

struct FieldElement<Msg> {
	let key: String
	let props: [FieldProps<Msg>]
	
	private func makeDefault() -> UITextField {
		let field = UITextField()
		field.translatesAutoresizingMaskIntoConstraints = false
		return field
	}
	
	func prepare(existing: UIView?) -> UIView {
		return existing as? UITextField ?? makeDefault()
	}
	
	private func applyToView(_ view: UIView, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		guard let field = view as? UITextField else { return }
		
		field.removeTarget(nil, action: nil, for: .allEvents)
		props.forEach { $0.apply(to: field, registerEventHandler: registerEventHandler) }
	}
	
	func toElement() -> Element<Msg> {
		return Element(key: key, makeViewIfNeeded: prepare, applyToView: applyToView)
	}
}

public func field<Key: RawRepresentable, Msg>(_ key: Key, _ props: [FieldProps<Msg>]) -> Element<Msg> where Key.RawValue == String {
	return FieldElement(key: key.rawValue, props: props).toElement()
}


public enum ControlProps<Msg, Control: UIControl> : ViewProps {
	typealias View = Control
	
	case on(UIControlEvents, toMessage: (Control, UIEvent) -> Msg)
	case applyChange(ChangeApplier<Control>)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<Control, Value>, to value: Value) -> ControlProps {
		return .applyChange(ChangeApplier(keyPath, value: value))
	}
	
	fileprivate func apply(to control: Control, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		switch self {
		case let .on(controlEvents, toMessage):
			let key = String(describing: controlEvents)
			let (target, action) = registerEventHandler(key, MessageMaker(control: toMessage), EventHandlingOptions())
			control.addTarget(target, action: action, for: controlEvents)
		case let .applyChange(applier):
			applier.apply(to: control)
		}
	}
}

fileprivate struct ControlElement<Msg, Control: UIControl> {
	let key: String
	let props: [ControlProps<Msg, Control>]
	fileprivate var _makeDefaultControl: () -> Control
	
	func makeDefault() -> Control {
		let control = _makeDefaultControl()
		control.translatesAutoresizingMaskIntoConstraints = false
		return control
	}
	
	func prepare(existing: UIView?) -> UIView {
		return existing as? Control ?? makeDefault()
	}
	
	private func applyToView(_ view: UIView, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		guard let control = view as? Control else { return }
		
		control.removeTarget(nil, action: nil, for: .allEvents)
		props.forEach { $0.apply(to: control, registerEventHandler: registerEventHandler) }
	}
	
	func toElement() -> Element<Msg> {
		return Element(key: key, makeViewIfNeeded: prepare, applyToView: applyToView)
	}
}

public func control<Key: RawRepresentable, Msg, Control: UIControl>(makeDefault: @escaping () -> Control) -> (_ key: Key, _ props: [ControlProps<Msg, Control>]) -> Element<Msg> where Key.RawValue == String {
	return { key, props in
		return ControlElement(key: key.rawValue, props: props, _makeDefaultControl: makeDefault).toElement()
	}
}


extension ControlProps where Control : UIButton {
	public static func title(_ title: String, for controlState: UIControlState) -> ControlProps {
		return .applyChange(ChangeApplier(makeChanges: { $0.setTitle(title, for: controlState) }))
	}
	
	public static func onPress(_ makeMessage: @escaping () -> Msg) -> ControlProps {
		return .on(.touchUpInside) { (button: UIButton, event: UIEvent) in return makeMessage() }
	}
}

public func button<Key: RawRepresentable, Msg>(_ key: Key, type: UIButtonType = .system, _ props: [ControlProps<Msg, UIButton>]) -> Element<Msg> where Key.RawValue == String {
	return control(makeDefault: { UIButton(type: type) })(key, props)
}


extension ControlProps where Control : UISlider {
	public static func value(_ value: Float) -> ControlProps {
		return .set(\.value, to: value)
	}
	
	public static func minimumValue(_ value: Float) -> ControlProps {
		return .set(\.minimumValue, to: value)
	}
	
	public static func maximumValue(_ value: Float) -> ControlProps {
		return .set(\.maximumValue, to: value)
	}
	
	public static var isContinuous: ControlProps {
		return .set(\.isContinuous, to: true)
	}
}

public func slider<Key: RawRepresentable, Msg>(_ key: Key, _ props: [ControlProps<Msg, UISlider>]) -> Element<Msg> where Key.RawValue == String {
	return control(makeDefault: { UISlider() })(key, props)
}


extension ControlProps where Control : UIStepper {
	public static func value(_ value: Double) -> ControlProps {
		return .set(\.value, to: value)
	}
	
	public static func minimumValue(_ value: Double) -> ControlProps {
		return .set(\.minimumValue, to: value)
	}
	
	public static func maximumValue(_ value: Double) -> ControlProps {
		return .set(\.maximumValue, to: value)
	}
	
	public static var isContinuous: ControlProps {
		return .set(\.isContinuous, to: true)
	}
}

public func stepper<Key: RawRepresentable, Msg>(_ key: Key, _ props: [ControlProps<Msg, UIStepper>]) -> Element<Msg> where Key.RawValue == String {
	return control(makeDefault: { UIStepper() })(key, props)
}


public struct Segment {
	public enum Content {
		case title(String)
		case image(UIImage)
	}
	
	public var key: String
	public var content: Content
	public var enabled = true
	public var width: CGFloat = 0
	
	func add(to segmentedControl: UISegmentedControl, index: Int) {
		let maxIndex = segmentedControl.numberOfSegments
		switch content {
		case let .image(image):
			if index >= maxIndex {
				segmentedControl.insertSegment(with: image, at: index, animated: false)
			}
			else {
				segmentedControl.setImage(image, forSegmentAt: index)
			}
		case let .title(title):
			if index >= maxIndex {
				segmentedControl.insertSegment(withTitle: title, at: index, animated: false)
			}
			else {
				segmentedControl.setTitle(title, forSegmentAt: index)
			}
		}
		segmentedControl.setEnabled(enabled, forSegmentAt: index)
		segmentedControl.setWidth(width, forSegmentAt: index)
	}
}

public func segment<Key: RawRepresentable>(_ key: Key, _ content: Segment.Content, enabled: Bool = true, width: CGFloat = 0.0) -> Segment where Key.RawValue : CustomStringConvertible {
	return Segment(key: String(describing: key), content: content, enabled: enabled, width: width)
}

var segmentKeysAssociatedObjectKey = true

extension UISegmentedControl {
	public var selectedSegmentKey: String! {
		guard let segmentKeys = objc_getAssociatedObject(self, &segmentKeysAssociatedObjectKey) as? [String]
			else { return nil }
	
		let index = self.selectedSegmentIndex
		if index >= self.numberOfSegments {
			return nil
		}
		
		return segmentKeys[index]
	}
}

public enum SegmentedControlProps<Msg> : ViewProps {
	typealias View = UISegmentedControl
	
	case selectedKey(String)
	case segments([Segment])
	case applyChange(ChangeApplier<UISegmentedControl>)
	case on(UIControlEvents, toMessage: ((UISegmentedControl, UIEvent) -> Msg)?)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<UISegmentedControl, Value>, to value: Value) -> SegmentedControlProps {
		return .applyChange(ChangeApplier(keyPath, value: value))
	}
	
	struct CommitState {
		var selectedIndex: Int = UISegmentedControlNoSegment
		var segments: [Segment] = []
		var otherProps: [SegmentedControlProps<Msg>] = []
		
		init(props: [SegmentedControlProps<Msg>]) {
			var selectedKey: String? = nil
			
			for prop in props {
				switch prop {
				case let .selectedKey(key):
					selectedKey = key
				case let .segments(newSegments):
					segments.append(contentsOf: newSegments)
				default:
					otherProps.append(prop)
				}
			}
			
			if let selectedKey = selectedKey {
				for (index, segment) in segments.enumerated() {
					if segment.key == selectedKey {
						selectedIndex = index
						break
					}
				}
			}
		}
		
		fileprivate func apply(to control: UISegmentedControl, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
			for (index, segment) in segments.enumerated() {
				segment.add(to: control, index: index)
			}
			
			let currentCount = control.numberOfSegments
			let countToRemove = max(0, currentCount - segments.count)
			if countToRemove > 0 {
				for index in (currentCount - countToRemove) ..< currentCount {
					control.removeSegment(at: index, animated: false)
				}
			}
			
			control.selectedSegmentIndex = selectedIndex
			
			otherProps.forEach { $0.apply(to: control, registerEventHandler: registerEventHandler) }
			
			let segmentKeys = segments.map{ $0.key }
			objc_setAssociatedObject(control, &segmentKeysAssociatedObjectKey, segmentKeys, .OBJC_ASSOCIATION_COPY_NONATOMIC)
		}
	}
	
	fileprivate func apply(to segmentedControl: UISegmentedControl, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		switch self {
		case let .applyChange(applier):
			applier.apply(to: segmentedControl)
		case let .on(controlEvents, toMessage):
			let key = String(describing: controlEvents)
			let (target, action) = registerEventHandler(key, toMessage.map { MessageMaker(control: $0) } ?? MessageMaker(), EventHandlingOptions())
			segmentedControl.addTarget(target, action: action, for: controlEvents)
		default:
			break
		}
	}
}

struct SegmentedControlElement<Msg> {
	let key: String
	let props: [SegmentedControlProps<Msg>]
	
	private func makeDefault() -> UISegmentedControl {
		let control = UISegmentedControl()
		control.translatesAutoresizingMaskIntoConstraints = false
		return control
	}
	
	func prepare(existing: UIView?) -> UIView {
		return existing as? UISegmentedControl ?? makeDefault()
	}
	
	private func applyToView(_ view: UIView, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		guard let control = view as? UISegmentedControl else { return }
		
		control.removeTarget(nil, action: nil, for: .allEvents)
		
		let state = SegmentedControlProps.CommitState(props: props)
		state.apply(to: control, registerEventHandler: registerEventHandler)
	}
	
	func toElement() -> Element<Msg> {
		return Element(key: key, makeViewIfNeeded: prepare, applyToView: applyToView)
	}
}

public func segmentedControl<Key: RawRepresentable, Msg>(_ key: Key, _ props: [SegmentedControlProps<Msg>]) -> Element<Msg> where Key.RawValue == String {
	return SegmentedControlElement(key: key.rawValue, props: props).toElement()
}
