import UIKit

class GameboardView : UIView {
    var dimension: Int = 4
    var cornerRadius: CGFloat
    var tiles: Dictionary<IndexPath, TileView>
    
    let thinPadding: CGFloat = 3.0
    let thickPadding: CGFloat = 6.0
    
    lazy var tilePadding: CGFloat = dimension > 5 ? thinPadding : thickPadding
    var tileWidth: CGFloat = 30
    
    let provider = AppearanceProvider()
    
    let tilePopStartScale: CGFloat = 0.1
    let tilePopMaxScale: CGFloat = 1.1
    let tilePopDelay: TimeInterval = 0.05
    let tileExpandTime: TimeInterval = 0.20
    let tileContractTime: TimeInterval = 0.1
    
    let tileMergeStartScale: CGFloat = 1.0
    let tileMergeExpandTime: TimeInterval = 0.04
    let tileMergeContractTime: TimeInterval = 0.04
    
    let perSquareSlideDuration: TimeInterval = 0.1
    
    init(cornerRadius radius: CGFloat) {
        cornerRadius = radius
        tiles = Dictionary()
        super.init(frame: .zero)
        layer.cornerRadius = cornerRadius
        backgroundColor = .black
    }
    
    init(dimension d: Int, tileWidth width: CGFloat, tilePadding padding: CGFloat, cornerRadius radius: CGFloat, backgroundColor: UIColor, foregroundColor: UIColor) {
            assert(d > 0)
            dimension = d
            tileWidth = width
            cornerRadius = radius
            tiles = Dictionary()
            let sideLength = padding + CGFloat(dimension)*(width + padding)
            super.init(frame: CGRect(x: 0, y: 0, width: sideLength, height: sideLength))
            layer.cornerRadius = radius
            setupBackground(backgroundColor: backgroundColor, tileColor: foregroundColor)
        }
    
    // Clear the gameboard.
    func clearBoard() {
        for (_, tile) in tiles {
            tile.removeFromSuperview()
        }
        tiles.removeAll(keepingCapacity: true)
    }
    
    // Return whether a given position is valid. Used for bounds checking.
    func positionIsValid(_ pos: (Int, Int)) -> Bool {
        let (x, y) = pos
        return (x >= 0 && x < dimension && y >= 0 && y < dimension)
    }
    
    func setupBackground(backgroundColor bgColor: UIColor, tileColor: UIColor) {
        backgroundColor = .green//bgColor
        var xCursor = tilePadding
        var yCursor: CGFloat
        let bgRadius = (cornerRadius >= 2) ? cornerRadius - 2 : 0
        for _ in 0..<dimension {
            yCursor = tilePadding
            for _ in 0..<dimension {
                // Draw each tile
                let background = UIView(frame: CGRect(x: xCursor, y: yCursor, width: tileWidth, height: tileWidth))
                background.layer.cornerRadius = bgRadius
                background.backgroundColor = tileColor
                addSubview(background)
                yCursor += tilePadding + tileWidth
            }
            xCursor += tilePadding + tileWidth
        }
    }
    
    /// Update the gameboard by inserting a tile in a given location. The tile will be inserted with a 'pop' animation.
    func insertTile(at pos: (Int, Int), value: Int) {
        assert(positionIsValid(pos))
        let (row, col) = pos
        let x = tilePadding + CGFloat(col)*(tileWidth + tilePadding)
        let y = tilePadding + CGFloat(row)*(tileWidth + tilePadding)
        let r = (cornerRadius >= 2) ? cornerRadius - 2 : 0
        let tile = TileView(position: CGPoint(x: x, y: y), width: tileWidth, value: value, radius: r, delegate: provider)
        tile.layer.setAffineTransform(CGAffineTransform(scaleX: tilePopStartScale, y: tilePopStartScale))
        
        addSubview(tile)
        bringSubviewToFront(tile)
        tiles[IndexPath(row: row, section: col)] = tile
        
        // Add to board
        UIView.animate(withDuration: tileExpandTime, delay: tilePopDelay, options: UIView.AnimationOptions(),
                       animations: {
                        // Make the tile 'pop'
                        tile.layer.setAffineTransform(CGAffineTransform(scaleX: self.tilePopMaxScale, y: self.tilePopMaxScale))
        },
                       completion: { finished in
                        // Shrink the tile after it 'pops'
                        UIView.animate(withDuration: self.tileContractTime, animations: { () -> Void in
                            tile.layer.setAffineTransform(CGAffineTransform.identity)
                        })
        })
    }
    
    /// Update the gameboard by moving a single tile from one location to another. If the move is going to collapse two
    /// tiles into a new tile, the tile will 'pop' after moving to its new location.
    func moveOneTile(from: (Int, Int), to: (Int, Int), value: Int) {
        assert(positionIsValid(from) && positionIsValid(to))
        let (fromRow, fromCol) = from
        let (toRow, toCol) = to
        let fromKey = IndexPath(row: fromRow, section: fromCol)
        let toKey = IndexPath(row: toRow, section: toCol)
        
        // Get the tiles
        guard let tile = tiles[fromKey] else {
            assert(false, "placeholder error")
        }
        let endTile = tiles[toKey]
        
        // Make the frame
        var finalFrame = tile.frame
        finalFrame.origin.x = tilePadding + CGFloat(toCol)*(tileWidth + tilePadding)
        finalFrame.origin.y = tilePadding + CGFloat(toRow)*(tileWidth + tilePadding)
        
        // Update board state
        tiles.removeValue(forKey: fromKey)
        tiles[toKey] = tile
        
        // Animate
        let shouldPop = endTile != nil
        UIView.animate(withDuration: perSquareSlideDuration,
                       delay: 0.0,
                       options: UIView.AnimationOptions.beginFromCurrentState,
                       animations: {
                        // Slide tile
                        tile.frame = finalFrame
        },
                       completion: { (finished: Bool) -> Void in
                        tile.value = value
                        endTile?.removeFromSuperview()
                        if !shouldPop || !finished {
                            return
                        }
                        tile.layer.setAffineTransform(CGAffineTransform(scaleX: self.tileMergeStartScale, y: self.tileMergeStartScale))
                        // Pop tile
                        UIView.animate(withDuration: self.tileMergeExpandTime,
                                       animations: {
                                        tile.layer.setAffineTransform(CGAffineTransform(scaleX: self.tilePopMaxScale, y: self.tilePopMaxScale))
                        },
                                       completion: { finished in
                                        // Contract tile to original size
                                        UIView.animate(withDuration: self.tileMergeContractTime, animations: {
                                            tile.layer.setAffineTransform(CGAffineTransform.identity)
                                        })
                        })
        })
    }
    
    /// Update the gameboard by moving two tiles from their original locations to a common destination. This action always
    /// represents tile collapse, and the combined tile 'pops' after both tiles move into position.
    func moveTwoTiles(from: ((Int, Int), (Int, Int)), to: (Int, Int), value: Int) {
        assert(positionIsValid(from.0) && positionIsValid(from.1) && positionIsValid(to))
        let (fromRowA, fromColA) = from.0
        let (fromRowB, fromColB) = from.1
        let (toRow, toCol) = to
        let fromKeyA = IndexPath(row: fromRowA, section: fromColA)
        let fromKeyB = IndexPath(row: fromRowB, section: fromColB)
        let toKey = IndexPath(row: toRow, section: toCol)
        
        guard let tileA = tiles[fromKeyA] else {
            assert(false, "placeholder error")
        }
        guard let tileB = tiles[fromKeyB] else {
            assert(false, "placeholder error")
        }
        
        // Make the frame
        var finalFrame = tileA.frame
        finalFrame.origin.x = tilePadding + CGFloat(toCol)*(tileWidth + tilePadding)
        finalFrame.origin.y = tilePadding + CGFloat(toRow)*(tileWidth + tilePadding)
        
        // Update the state
        let oldTile = tiles[toKey]  // TODO: make sure this doesn't cause issues
        oldTile?.removeFromSuperview()
        tiles.removeValue(forKey: fromKeyA)
        tiles.removeValue(forKey: fromKeyB)
        tiles[toKey] = tileA
        
        UIView.animate(withDuration: perSquareSlideDuration,
                       delay: 0.0,
                       options: UIView.AnimationOptions.beginFromCurrentState,
                       animations: {
                        // Slide tiles
                        tileA.frame = finalFrame
                        tileB.frame = finalFrame
        },
                       completion: { finished in
                        tileA.value = value
                        tileB.removeFromSuperview()
                        if !finished {
                            return
                        }
                        tileA.layer.setAffineTransform(CGAffineTransform(scaleX: self.tileMergeStartScale, y: self.tileMergeStartScale))
                        // Pop tile
                        UIView.animate(withDuration: self.tileMergeExpandTime,
                                       animations: {
                                        tileA.layer.setAffineTransform(CGAffineTransform(scaleX: self.tilePopMaxScale, y: self.tilePopMaxScale))
                        },
                                       completion: { finished in
                                        // Contract tile to original size
                                        UIView.animate(withDuration: self.tileMergeContractTime, animations: {
                                            tileA.layer.setAffineTransform(CGAffineTransform.identity)
                                        })
                        })
        })
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
}
