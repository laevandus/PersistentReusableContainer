import UIKit

// MARK: -

final class Container<Key: Hashable & RawRepresentable> {
    private var storage = [Key: [ContainerItem]]() {
        didSet {
            didChange()
        }
    }
    
    init(content: [Key: [ContainerItem]] = [:]) {
        storage = content
    }
    
    func add(_ item: ContainerItem, key: Key) {
        if var current = storage[key] {
            current.append(item)
            storage[key] = current
        }
        else {
            storage[key] = [item]
        }
    }
    
    func items<T: ContainerItem>(forKey key: Key) -> [T] {
        guard let all = storage[key] else { return [] }
        return all as! [T]
    }
    
    var didChange: () -> Void = {}
}

protocol ContainerItem {
    init?(jsonData: Data)
    var jsonDataRepresentation: Data { get }
}

extension ContainerItem where Self: Codable {
    init?(jsonData: Data) {
        guard let object = try? JSONDecoder().decode(Self.self, from: jsonData) else { return nil }
        self = object
    }
    
    var jsonDataRepresentation: Data {
        return try! JSONEncoder().encode(self)
    }
}

// MARK: -

struct EventItem: ContainerItem, Codable {
    let date: Date
    let title: String
    let description: String
}

struct NoteItem: ContainerItem, Codable {
    let text: String
}

enum CalendarKeys: String {
    case homeEvents, workEvents, notes
}

// MARK: - Persistence

extension Container where Key == CalendarKeys {
    convenience init(contentsOfURL url: URL) throws {
        let data = try Data(contentsOf: url)
        let contents = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as! [Key.RawValue: [Data]]
        let converted = contents.compactMap({ (keyValuePair) -> (Key, [ContainerItem])? in
            guard let key = Key(rawValue: keyValuePair.key) else { return nil }
            switch key {
            case .homeEvents, .workEvents:
                return (key, keyValuePair.value.compactMap({ EventItem(jsonData: $0) }))
            case .notes:
                return (key, keyValuePair.value.compactMap({ NoteItem(jsonData: $0) }))
            }
        })
        self.init(content: Dictionary(uniqueKeysWithValues: converted))
    }
}

extension Container where Key.RawValue == String {
    func write(to url: URL) throws {
        let converted = storage.map { (keyValuePair) -> (String, [Data]) in
            return (keyValuePair.key.rawValue, keyValuePair.value.map({ $0.jsonDataRepresentation }))
        }
        let data = try NSKeyedArchiver.archivedData(withRootObject: Dictionary(uniqueKeysWithValues: converted), requiringSecureCoding: false)
        try data.write(to: url, options: .atomicWrite)
    }
}

let container = Container<CalendarKeys>()

let event1 = EventItem(date: Date(), title: "title1", description: "description1")
container.add(event1, key: .homeEvents)

let event2 = EventItem(date: Date(), title: "title2", description: "description2")
container.add(event2, key: .workEvents)

let note1 = NoteItem(text: "text3")
container.add(note1, key: .notes)

let homeEvents: [EventItem] = container.items(forKey: .homeEvents)
let workEvents: [EventItem] = container.items(forKey: .workEvents)
let notes: [NoteItem] = container.items(forKey: .notes)
print("Home events: ", homeEvents)
print("Work events: ", workEvents)
print("Notes: ", notes)

let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Test")
do {
    try container.write(to: url)
}
catch {
    print(error as NSError)
}

do {
    let restoredContainer = try Container<CalendarKeys>(contentsOfURL: url)
    let homeEvents: [EventItem] = restoredContainer.items(forKey: .homeEvents)
    let workEvents: [EventItem] = restoredContainer.items(forKey: .workEvents)
    let notes: [NoteItem] = restoredContainer.items(forKey: .notes)
    print("Home events: ", homeEvents)
    print("Work events: ", workEvents)
    print("Notes: ", notes)
}
catch {
    print(error as NSError)
}

