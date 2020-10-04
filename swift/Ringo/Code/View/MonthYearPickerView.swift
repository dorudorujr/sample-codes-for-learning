//
//  MonthYearPickerView.swift
//  RingoPass
//
//  Created by 杉岡 成哉 on 2019/07/01.
//  Copyright © 2019年 Team Lab. All rights reserved.
//

import UIKit

open class MonthYearPickerView: UIControl {
    
    /// default is current date when picker created
    open var date: Date = Date() {
        didSet {
            let newDate = calendar.startOfDay(for: date)
            setDate(newDate, animated: true)
            sendActions(for: .valueChanged)
        }
    }
    
    /// default is current calendar when picker created
    open var calendar: Calendar = Calendar.autoupdatingCurrent {
        didSet {
            monthDateFormatter.calendar = calendar
            monthDateFormatter.timeZone = calendar.timeZone
            yearDateFormatter.calendar = calendar
            yearDateFormatter.timeZone = calendar.timeZone
        }
    }
    
    /// default is nil
    open var locale: Locale? {
        didSet {
            calendar.locale = locale
            monthDateFormatter.locale = locale
            yearDateFormatter.locale = locale
        }
    }
    
    lazy fileprivate var pickerView: UIPickerView = {
        let pickerView = UIPickerView(frame: self.bounds)
        pickerView.dataSource = self
        pickerView.delegate = self
        pickerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return pickerView
    }()
    
    lazy fileprivate var monthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter
    }()
    
    lazy fileprivate var yearDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("y")
        return formatter
    }()
    
    fileprivate enum Component: Int {
        case month
        case year
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        initialSetup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialSetup()
    }
    
    private func initialSetup() {
        addSubview(pickerView)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        setDate(date, animated: false)
    }
    
    /// if animated is YES, animate the wheels of time to display the new date
    open func setDate(_ date: Date, animated: Bool) {
        guard let yearRange = calendar.maximumRange(of: .year), let monthRange = calendar.maximumRange(of: .month) else {
            return
        }
        let month = calendar.component(.month, from: date) - monthRange.lowerBound
        pickerView.selectRow(month, inComponent: Component.month.rawValue, animated: animated)
        let year = calendar.component(.year, from: date) - yearRange.lowerBound
        pickerView.selectRow(year, inComponent: Component.year.rawValue, animated: animated)
    }
    
}

extension MonthYearPickerView: UIPickerViewDelegate {
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard let yearRange = calendar.maximumRange(of: .year), let monthRange = calendar.maximumRange(of: .month) else {
            return
        }
        var dateComponents = DateComponents()
        dateComponents.year = yearRange.lowerBound + pickerView.selectedRow(inComponent: Component.year.rawValue)
        dateComponents.month = monthRange.lowerBound + pickerView.selectedRow(inComponent: Component.month.rawValue)
        guard let date = calendar.date(from: dateComponents) else {
            return
        }
        self.date = date
    }
    
}

extension MonthYearPickerView: UIPickerViewDataSource {
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        
        guard let component = Component(rawValue: component) else { return 0 }
        switch component {
        case .month:
            guard let range = calendar.maximumRange(of: .month) else {
                return 0
            }
            return range.count
        case .year:
            guard let range = calendar.maximumRange(of: .year) else {
                return 0
            }
            return range.count
        }
        
    }
    
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        guard let component = Component(rawValue: component) else { return nil }
        
        switch component {
        case .month:
            guard let range = calendar.maximumRange(of: .month) else {
                return nil
            }
            let month = range.lowerBound + row
            var dateComponents = DateComponents()
            dateComponents.month = month
            guard let date = calendar.date(from: dateComponents) else {
                return nil
            }
            return monthDateFormatter.string(from: date)
        case .year:
            guard let range = calendar.maximumRange(of: .year) else {
                return nil
            }
            let year = range.lowerBound + row
            var dateComponents = DateComponents()
            dateComponents.year = year
            guard let date = calendar.date(from: dateComponents) else {
                return nil
            }
            return yearDateFormatter.string(from: date)
        }
        
    }
    
}
