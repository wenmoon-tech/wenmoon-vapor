import Vapor

struct FearAndGreedIndex: Content, Equatable {
    struct FearAndGreedData: Content, Equatable {
        let value: String
        let valueClassification: String
    }
    
    let data: [FearAndGreedData]
}
