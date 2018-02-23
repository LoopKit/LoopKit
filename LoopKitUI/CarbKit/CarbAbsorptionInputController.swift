//
//  CarbAbsorptionInputController.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import UIKit

class CarbAbsorptionInputController: UIInputViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, IdentifiableClass {

    override func viewDidLoad() {
        super.viewDidLoad()

        inputView = view as? UIInputView
        inputView?.allowsSelfSizing = true
        view.translatesAutoresizingMaskIntoConstraints = false

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionHeadersPinToVisibleBounds = true
            layout.sectionFootersPinToVisibleBounds = true
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBOutlet weak var collectionView: UICollectionView!

    @IBOutlet weak var sectionIndex: UIStackView!

    weak var delegate: CarbAbsorptionInputControllerDelegate?

    lazy var food = FoodEmojiDataSource()

    // MARK: - Actions

    @IBAction func switchKeyboard(_ sender: Any) {
        delegate?.carbAbsorptionInputControllerDidAdvanceToStandardInputMode(self)
    }

    @IBAction func deleteBackward(_ sender: Any) {
        inputView?.playInputClick​()
        textDocumentProxy.deleteBackward()
    }

    @IBAction func indexTouched(_ sender: UIGestureRecognizer) {
        let xLocation = max(0, sender.location(in: sectionIndex).x / sectionIndex.frame.width)
        let items = sectionIndex.arrangedSubviews.count
        let section = min(items - 1, Int(xLocation * CGFloat(items)))

        collectionView.scrollToItem(at: IndexPath(item: 0, section: section), at: .left, animated: false)
    }

    // MARK: - UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return food.sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return food.sections[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let cell = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: kind == UICollectionElementKindSectionHeader ? CarbAbsorptionInputHeaderView.className : "Footer", for: indexPath)

        if let cell = cell as? CarbAbsorptionInputHeaderView {
            cell.titleLabel.text = food.sections[indexPath.section].title.localizedUppercase
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CarbAbsorptionInputCell.className, for: indexPath) as! CarbAbsorptionInputCell

        cell.label.text = food.sections[indexPath.section].items[indexPath.row]

        return cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        inputView?.playInputClick​()
        textDocumentProxy.insertText(food.sections[indexPath.section].items[indexPath.row])

        delegate?.carbAbsorptionInputControllerDidSelectItemInSection(indexPath.section)
    }
}


protocol CarbAbsorptionInputControllerDelegate: class {
    func carbAbsorptionInputControllerDidAdvanceToStandardInputMode(_ controller: CarbAbsorptionInputController) -> Void

    func carbAbsorptionInputControllerDidSelectItemInSection(_ section: Int) -> Void
}


extension UIInputView: UIInputViewAudioFeedback {
    public var enableInputClicksWhenVisible: Bool { return true }

    func playInputClick​() {
        let device = UIDevice.current
        device.playInputClick()
    }
}
