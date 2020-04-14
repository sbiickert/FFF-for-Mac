import UIKit


func random() -> Double {
	let value = Double(arc4random_uniform(100))
	//print("Random: \(value)")
	return value
}

func randomAdjusted(input: Double) -> Double {
	let randomValue = random()
	var adjusted = input
	switch randomValue {
	case 0..<25:
		adjusted *= 0.9
	case 0..<50:
		adjusted *= 1.0
	case 0..<75:
		adjusted *= 1.5
	default:
		adjusted *= 2.0
	}
	//print("Adjusted: \(adjusted)")
	return adjusted
}

print(randomAdjusted(input: 0.05))
print(randomAdjusted(input: 0.5))
print(randomAdjusted(input: 5.0))
print(randomAdjusted(input: 50.0))
