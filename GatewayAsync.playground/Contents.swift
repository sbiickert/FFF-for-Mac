import UIKit

let dateStr = "2/28/2018"
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "MM/dd/yyyy"

let date = dateFormatter.date(from: dateStr)

var temp:String?
print("hi there \(String(describing: temp))")

