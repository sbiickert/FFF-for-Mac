import UIKit

let searchString = "created transaction 20295"
let createdTransactionIDRegEx = "\\d+"
do {
	let regex = try NSRegularExpression(pattern: createdTransactionIDRegEx, options: NSRegularExpression.Options.caseInsensitive)
	let results = regex.matches(in: searchString, range: NSRange(searchString.startIndex..., in: searchString))
	
	let matches = results.map {
		String(searchString[Range($0.range, in: searchString)!])
	}
}
