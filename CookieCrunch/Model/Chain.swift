//
//  Chain.swift
//  CookieCrunch
//
//  Created by Anton Novoselov on 30/06/2017.
//  Copyright © 2017 Anton Novoselov. All rights reserved.
//

class Chain: Hashable, CustomStringConvertible {
    // The Cookies that are part of this chain.
    var cookies = [Cookie]()
    
    enum ChainType: CustomStringConvertible {
        case horizontal
        case vertical
        
        // Note: add any other shapes you want to detect to this list.
        //case ChainTypeLShape
        //case ChainTypeTShape
        
        var description: String {
            switch self {
            case .horizontal: return "Horizontal"
            case .vertical: return "Vertical"
            }
        }
    }
    
    // Whether this chain is horizontal or vertical.
    var chainType: ChainType
    
    // How many points this chain is worth.
    var score = 0
    
    init(chainType: ChainType) {
        self.chainType = chainType
    }
    
    func add(cookie: Cookie) {
        cookies.append(cookie)
    }
    
    func firstCookie() -> Cookie {
        return cookies[0]
    }
    
    func lastCookie() -> Cookie {
        return cookies[cookies.count - 1]
    }
    
    var length: Int {
        return cookies.count
    }
    
    var description: String {
        return "type:\(chainType) cookies:\(cookies)"
    }
    
    var hashValue: Int {
        return cookies.reduce (0) { $0.hashValue ^ $1.hashValue }
    }
    
}

func ==(lhs: Chain, rhs: Chain) -> Bool {
    return lhs.cookies == rhs.cookies
}

