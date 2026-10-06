import Foundation
import CoreGraphics

// MARK: - Knotentypen

enum NodeKind: String, Codable, CaseIterable, Identifiable {
    case classType, abstractClass, interface, enumeration, note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classType: "Klasse"
        case .abstractClass: "Abstrakt"
        case .interface: "Interface"
        case .enumeration: "Enum"
        case .note: "Notiz"
        }
    }

    var longTitle: String {
        switch self {
        case .classType: "Klasse"
        case .abstractClass: "Abstrakte Klasse"
        case .interface: "Interface"
        case .enumeration: "Enumeration"
        case .note: "Notiz"
        }
    }

    var icon: Icon {
        switch self {
        case .classType: .classBox
        case .abstractClass: .abstractClass
        case .interface: .interface
        case .enumeration: .enumeration
        case .note: .note
        }
    }

    var namePrefix: String {
        switch self {
        case .classType: "Klasse"
        case .abstractClass: "AbstrakteKlasse"
        case .interface: "Interface"
        case .enumeration: "Enum"
        case .note: "Notiz"
        }
    }

    var stereotype: String? {
        switch self {
        case .interface: "«interface»"
        case .enumeration: "«enumeration»"
        default: nil
        }
    }
}

enum Visibility: String, Codable, CaseIterable, Identifiable {
    case publicAccess = "+", privateAccess = "-", protectedAccess = "#", packageAccess = "~"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .publicAccess: "public"
        case .privateAccess: "private"
        case .protectedAccess: "protected"
        case .packageAccess: "package"
        }
    }
}

struct Member: Identifiable, Codable, Hashable {
    var id = UUID()
    var visibility: Visibility = .privateAccess
    var text: String
    var isStatic = false
    var isAbstract = false
}

struct UMLNode: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: NodeKind
    var name: String
    var attributes: [Member] = []
    var operations: [Member] = []
    var noteText: String = ""
    var origin: CGPoint
    var customWidth: CGFloat? = nil

    var displayName: String {
        if kind == .note {
            let first = noteText.split(separator: "\n").first.map(String.init) ?? ""
            return first.isEmpty ? "Notiz" : first
        }
        return name.isEmpty ? "Unbenannt" : name
    }
}

// MARK: - Beziehungen

enum Decoration: Equatable {
    case none, openArrow, hollowTriangle, hollowDiamond, filledDiamond
}

enum RelationKind: String, Codable, CaseIterable, Identifiable {
    case association, directedAssociation, inheritance, realization, aggregation, composition, dependency, anchor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .association: "Assoziation"
        case .directedAssociation: "Gerichtete Assoziation"
        case .inheritance: "Vererbung"
        case .realization: "Realisierung"
        case .aggregation: "Aggregation"
        case .composition: "Komposition"
        case .dependency: "Abhängigkeit"
        case .anchor: "Notiz-Anker"
        }
    }

    var shortTitle: String {
        switch self {
        case .directedAssociation: "Gerichtet"
        case .anchor: "Anker"
        default: title
        }
    }

    var icon: Icon {
        switch self {
        case .association: .association
        case .directedAssociation: .directed
        case .inheritance: .inheritance
        case .realization: .realization
        case .aggregation: .aggregation
        case .composition: .composition
        case .dependency: .dependency
        case .anchor: .anchor
        }
    }

    var isDashed: Bool { self == .realization || self == .dependency || self == .anchor }

    var decoration: Decoration {
        switch self {
        case .association, .anchor: .none
        case .directedAssociation, .dependency: .openArrow
        case .inheritance, .realization: .hollowTriangle
        case .aggregation: .hollowDiamond
        case .composition: .filledDiamond
        }
    }

    var hint: String {
        switch self {
        case .association: "Ungerichtete Beziehung zwischen zwei Elementen."
        case .directedAssociation: "Die Quelle kennt das Ziel."
        case .inheritance: "Die Quelle erbt vom Ziel."
        case .realization: "Die Quelle implementiert das Ziel (meist ein Interface)."
        case .aggregation: "Das Ziel ist das Ganze, die Quelle ein Teil davon."
        case .composition: "Wie Aggregation – das Teil existiert nicht ohne das Ganze."
        case .dependency: "Die Quelle benutzt das Ziel."
        case .anchor: "Verbindet eine Notiz mit einem Element."
        }
    }
}

struct UMLRelation: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: RelationKind
    var from: UUID
    var to: UUID
    var label: String = ""
    var fromMultiplicity: String = ""
    var toMultiplicity: String = ""
}

// MARK: - Diagramm

struct Diagram: Codable, Equatable {
    var formatVersion = 1
    var name: String
    var nodes: [UMLNode] = []
    var relations: [UMLRelation] = []
}

// MARK: - Fehlertolerantes Decoding (ältere/ unvollständige Dateien)

extension Member {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        visibility = try c.decodeIfPresent(Visibility.self, forKey: .visibility) ?? .privateAccess
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        isStatic = try c.decodeIfPresent(Bool.self, forKey: .isStatic) ?? false
        isAbstract = try c.decodeIfPresent(Bool.self, forKey: .isAbstract) ?? false
    }
}

extension UMLNode {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(NodeKind.self, forKey: .kind) ?? .classType
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        attributes = try c.decodeIfPresent([Member].self, forKey: .attributes) ?? []
        operations = try c.decodeIfPresent([Member].self, forKey: .operations) ?? []
        noteText = try c.decodeIfPresent(String.self, forKey: .noteText) ?? ""
        origin = try c.decodeIfPresent(CGPoint.self, forKey: .origin) ?? .zero
        customWidth = try c.decodeIfPresent(CGFloat.self, forKey: .customWidth)
    }
}

extension UMLRelation {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(RelationKind.self, forKey: .kind) ?? .association
        from = try c.decode(UUID.self, forKey: .from)
        to = try c.decode(UUID.self, forKey: .to)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        fromMultiplicity = try c.decodeIfPresent(String.self, forKey: .fromMultiplicity) ?? ""
        toMultiplicity = try c.decodeIfPresent(String.self, forKey: .toMultiplicity) ?? ""
    }
}

extension Diagram {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try c.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Diagramm"
        nodes = try c.decodeIfPresent([UMLNode].self, forKey: .nodes) ?? []
        let ids = Set(nodes.map(\.id))
        relations = (try c.decodeIfPresent([UMLRelation].self, forKey: .relations) ?? [])
            .filter { ids.contains($0.from) && ids.contains($0.to) }
    }
}

// MARK: - Vorlagen

extension UMLNode {
    static let placeholder = UMLNode(kind: .classType, name: "", origin: .zero)

    static func template(_ kind: NodeKind, index: Int) -> UMLNode {
        var n = UMLNode(kind: kind, name: "\(kind.namePrefix)\(index)", origin: .zero)
        switch kind {
        case .classType:
            n.attributes = [Member(text: "id: int")]
            n.operations = [Member(visibility: .publicAccess, text: "ausfuehren(): void")]
        case .abstractClass:
            n.attributes = [Member(visibility: .protectedAccess, text: "name: String")]
            n.operations = [Member(visibility: .publicAccess, text: "berechne(): double", isAbstract: true)]
        case .interface:
            n.operations = [Member(visibility: .publicAccess, text: "methode(): void", isAbstract: true)]
        case .enumeration:
            n.attributes = [Member(visibility: .publicAccess, text: "WERT_A"),
                            Member(visibility: .publicAccess, text: "WERT_B")]
        case .note:
            n.name = ""
            n.noteText = "Neue Notiz"
        }
        return n
    }
}

extension Diagram {
    static func sample() -> Diagram {
        func m(_ v: Visibility, _ t: String, isStatic: Bool = false, isAbstract: Bool = false) -> Member {
            Member(visibility: v, text: t, isStatic: isStatic, isAbstract: isAbstract)
        }

        let fahrbar = UMLNode(kind: .interface, name: "Fahrbar",
                              operations: [m(.publicAccess, "fahren(km: double): void", isAbstract: true),
                                           m(.publicAccess, "bremsen(): void", isAbstract: true)],
                              origin: .zero)
        let fahrzeug = UMLNode(kind: .abstractClass, name: "Fahrzeug",
                               attributes: [m(.protectedAccess, "kennzeichen: String"),
                                            m(.protectedAccess, "baujahr: int"),
                                            m(.privateAccess, "kmStand: double"),
                                            m(.privateAccess, "anzahl: int", isStatic: true)],
                               operations: [m(.publicAccess, "getAlter(): int"),
                                            m(.publicAccess, "fahren(km: double): void"),
                                            m(.publicAccess, "wartung(): void", isAbstract: true)],
                               origin: .zero)
        let auto = UMLNode(kind: .classType, name: "Auto",
                           attributes: [m(.privateAccess, "tueren: int"),
                                        m(.privateAccess, "kraftstoff: Kraftstoff")],
                           operations: [m(.publicAccess, "tanken(liter: double): void"),
                                        m(.publicAccess, "wartung(): void")],
                           origin: .zero)
        let motorrad = UMLNode(kind: .classType, name: "Motorrad",
                               attributes: [m(.privateAccess, "hatBeiwagen: boolean")],
                               operations: [m(.publicAccess, "wartung(): void")],
                               origin: .zero)
        let motor = UMLNode(kind: .classType, name: "Motor",
                            attributes: [m(.privateAccess, "leistungKW: int"),
                                         m(.privateAccess, "hubraum: int")],
                            operations: [m(.publicAccess, "starten(): boolean")],
                            origin: .zero)
        let kraftstoff = UMLNode(kind: .enumeration, name: "Kraftstoff",
                                 attributes: ["BENZIN", "DIESEL", "ELEKTRO", "HYBRID"].map { m(.publicAccess, $0) },
                                 origin: .zero)
        let fuhrpark = UMLNode(kind: .classType, name: "Fuhrpark",
                               attributes: [m(.privateAccess, "name: String")],
                               operations: [m(.publicAccess, "hinzufuegen(f: Fahrzeug): void"),
                                            m(.publicAccess, "suche(kz: String): Fahrzeug")],
                               origin: .zero)
        var note = UMLNode(kind: .note, name: "", origin: .zero)
        note.noteText = "Alle Fahrzeuge werden\nzentral im Fuhrpark verwaltet."

        var d = Diagram(name: "Fuhrpark")
        d.nodes = [fuhrpark, fahrbar, fahrzeug, auto, motorrad, motor, kraftstoff, note]
        d.relations = [
            UMLRelation(kind: .realization, from: fahrzeug.id, to: fahrbar.id),
            UMLRelation(kind: .inheritance, from: auto.id, to: fahrzeug.id),
            UMLRelation(kind: .inheritance, from: motorrad.id, to: fahrzeug.id),
            UMLRelation(kind: .composition, from: motor.id, to: auto.id, fromMultiplicity: "1", toMultiplicity: "1"),
            UMLRelation(kind: .aggregation, from: fahrzeug.id, to: fuhrpark.id, label: "verwaltet",
                        fromMultiplicity: "0..*", toMultiplicity: "1"),
            UMLRelation(kind: .directedAssociation, from: auto.id, to: kraftstoff.id, label: "nutzt"),
            UMLRelation(kind: .anchor, from: note.id, to: fuhrpark.id)
        ]

        let positions = AutoLayout.arrange(d)
        for i in d.nodes.indices {
            if let p = positions[d.nodes[i].id] { d.nodes[i].origin = p }
        }
        return d
    }
}

// MARK: - PlantUML

extension Diagram {
    func plantUML() -> String {
        var aliases: [UUID: String] = [:]
        var out = ["@startuml", "skinparam classAttributeIconSize 0"]
        if !name.isEmpty { out.append("title \(name)") }
        out.append("")

        for (i, n) in nodes.enumerated() {
            let alias = "N\(i + 1)"
            aliases[n.id] = alias
            let safeName = n.name.replacingOccurrences(of: "\"", with: "'")
            switch n.kind {
            case .note:
                let text = n.noteText
                    .replacingOccurrences(of: "\"", with: "'")
                    .replacingOccurrences(of: "\n", with: "\\n")
                out.append("note \"\(text)\" as \(alias)")
            default:
                let keyword: String = switch n.kind {
                case .abstractClass: "abstract class"
                case .interface: "interface"
                case .enumeration: "enum"
                default: "class"
                }
                out.append("\(keyword) \"\(safeName)\" as \(alias) {")
                for a in n.attributes {
                    out.append("  " + Self.plantMember(a, enumLiteral: n.kind == .enumeration))
                }
                if n.kind == .enumeration, !n.operations.isEmpty { out.append("  --") }
                for o in n.operations {
                    out.append("  " + Self.plantMember(o, enumLiteral: false))
                }
                out.append("}")
            }
        }

        out.append("")
        for r in relations {
            guard let f = aliases[r.from], let t = aliases[r.to] else { continue }
            let fm = r.fromMultiplicity.isEmpty ? "" : " \"\(r.fromMultiplicity)\""
            let tm = r.toMultiplicity.isEmpty ? "" : " \"\(r.toMultiplicity)\""
            let label = r.label.isEmpty ? "" : " : \(r.label)"
            let line: String = switch r.kind {
            case .association: "\(f)\(fm) --\(tm) \(t)"
            case .directedAssociation: "\(f)\(fm) -->\(tm) \(t)"
            case .dependency: "\(f)\(fm) ..>\(tm) \(t)"
            case .anchor: "\(f) .. \(t)"
            case .inheritance: "\(t)\(tm) <|--\(fm) \(f)"
            case .realization: "\(t)\(tm) <|..\(fm) \(f)"
            case .aggregation: "\(t)\(tm) o--\(fm) \(f)"
            case .composition: "\(t)\(tm) *--\(fm) \(f)"
            }
            out.append(line + label)
        }
        out.append("@enduml")
        return out.joined(separator: "\n")
    }

    private static func plantMember(_ m: Member, enumLiteral: Bool) -> String {
        if enumLiteral { return m.text }
        var s = ""
        if m.isStatic { s += "{static} " }
        if m.isAbstract { s += "{abstract} " }
        return s + m.visibility.rawValue + m.text
    }
}
