//
//  Scheduler.swift
//  Anki
//
//  Created by Labuser on 3/22/16.
//  Copyright © 2016 TeamKickAss. All rights reserved.
//

import UIKit
import Parse

enum CardDifficulty{
    case Again
    case Hard
    case Good
    case Easy
    case New
}

enum CardStatus{
    case Viewed
    case Waiting
}

enum SchedulerStatus{
    case Ready
    case Initializing
    case Done
    case OutOfCards
    case Error
}

class Scheduler: NSObject {
    
    //Scheduling Options
    var cardsPerDay = 30
    var numStudied = 0
    //In seconds
    var timeAgainHard = 60.0
    var timeAgainGood = 600.0
    var timeAgainEasy = 86400.0
    
    
    var rootCard: CardNode? //List of cards that haven't been studied yet. Card is studied when it is marked easy.
    var lastCard: CardNode?
    var currentCard: CardNode?
    var cardArr: [CardNode]
    
    var doneCard: CardNode? //List of cards that you've done studying
    var status = SchedulerStatus.Initializing{
        didSet{
            onStatusChange(status: status)
        }
    }
    var onStatusChange: (status: SchedulerStatus) -> Void
    
    init(deck: Deck, onStatusChange: (status: SchedulerStatus) -> Void){
        self.cardArr = [CardNode]()
        self.onStatusChange = onStatusChange
        super.init()
        DeckUtil.getCardsForDeck(deck, withCompletion: self.gotNewCards)
        
    }
    
    func gotNewCards(cards: [Card]?, error: NSError?){
        if let cards = cards{
            if !cards.isEmpty{
                cardArr = [CardNode]()
                var i = 0
                for ; i < cards.count; i = i+1{
                    if i == 0 {
                        cardArr.append(CardNode(card: cards[i], index: i, difficulty: .New, prev: nil, next: nil))
                        rootCard = cardArr[i]
                        currentCard = cardArr[i]
                    }else{
                        cardArr.append(CardNode(card: cards[i], index: i, difficulty: .New, prev: cardArr[i-1] , next: nil))
                        cardArr[i-1].next = cardArr[i]
                    }
                }
                lastCard = cardArr[i-1]
            }
        }
        status = .Ready
    }
    
    func getNextCard() -> Card?{
        let card = currentCard?.card
        lastCard = currentCard
        lastCard?.status = .Viewed
        if currentCard?.next == nil{
            status = .OutOfCards
        }else{
            currentCard = currentCard?.next
        }
        return card
    }
    
    func setLastCard(difficulty: CardDifficulty){
        lastCard?.difficulty = difficulty
        if(difficulty == .Easy){
            //Remove Card
            if let prev = lastCard?.prev{
                prev.next = lastCard?.next
            }
            
            if let next = lastCard?.next{
                next.prev = lastCard?.prev
            }
            //Increase the numStudied
            numStudied++
            //Move it to the done list
            if doneCard != nil {
                doneCard?.prev = lastCard
                lastCard?.next = doneCard
                
                doneCard = lastCard
            }
        //For now insert the card after the current card.
        }else{
            if let currentCard = currentCard{
                var next = currentCard.next
                if let next = next{
                    next.prev = lastCard
                }
                currentCard.next = lastCard
                lastCard?.prev = currentCard
                lastCard?.next = next
            }
        }
    }
    
    func restart(){
        currentCard = cardArr[0]
        lastCard = currentCard
    }
    
    // shuffle Maintains Following Properties
    // New Cards always at the end
    // Hard Cards usually before Good Cards
    
    func switchNodes(x: CardNode, y: CardNode){
        let xNext = x.next
        let xPrev = x.prev
        
        let yNext = y.next
        let yPrev = y.prev
        
        x.next = yNext
        x.prev = yPrev
        
        y.next = xNext
        y.prev = yPrev
        
        xNext?.prev = y
        xPrev?.next = y
        
        yNext?.prev = x
        yPrev?.prev = x
        
    }
    func shuffle(from: CardNode, to: CardNode){
        //Random Shuffle
        var currentIndex = cardArr.count
        
        while (0 != currentIndex){
            let randomIndex = random() % currentIndex
            currentIndex = currentIndex - 1
            
            switchNodes(cardArr[currentIndex], y: cardArr[randomIndex])
            
        }
        rootCard = cardArr[0]
        currentCard = cardArr[0]
    }
    
    
    class CardNode {
        let index: Int
        let card: Card
        var difficulty: CardDifficulty
        var prev: CardNode?
        var next: CardNode?
        var status: CardStatus
        var lastViewed: NSDate?
        init(card: Card, index: Int, difficulty: CardDifficulty, prev: CardNode?, next: CardNode?){
            self.card = card
            self.difficulty = difficulty
            self.prev = prev
            self.next = next
            self.status = .Waiting
            self.index = index
        }
        
        func equals(card: CardNode) -> Bool{
            return self.index == card.index
        }
    }
}

