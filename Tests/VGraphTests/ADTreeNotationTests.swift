import App
import TestSupport
import Testing

@testable import VGLanguage
@testable import VGraph

@Suite
struct ADTreeNotationTests {

    // MARK: - Notation Setup Tests

    @Test func testADTreeNotationHasAllNodeTypes() throws {
        var graph = VGraph()
        graph = try Notations.ADTree.addNotation(addTo: graph)

        #expect(graph.has(nodeType: Notations.ADTree.NodeTypes.attack))
        #expect(graph.has(nodeType: Notations.ADTree.NodeTypes.defense))
        #expect(graph.has(nodeType: Notations.ADTree.NodeTypes.andJunctor))
    }

    @Test func testADTreeNotationHasAllEdgeTypes() throws {
        var graph = VGraph()
        graph = try Notations.ADTree.addNotation(addTo: graph)

        #expect(graph.has(edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack.id))
        #expect(graph.has(edgeType: Notations.ADTree.EdgeTypes.defenseRefinesDefense.id))

        #expect(graph.has(edgeType: Notations.ADTree.EdgeTypes.defenseCountersAttack.id))
        #expect(graph.has(edgeType: Notations.ADTree.EdgeTypes.attackCountersDefense.id))

        #expect(graph.has(edgeType: Notations.ADTree.EdgeTypes.attackToAndJunctor.id))
        #expect(graph.has(edgeType: Notations.ADTree.EdgeTypes.defenseToAndJunctor.id))
        #expect(graph.has(edgeType: Notations.ADTree.EdgeTypes.andJunctorToAttack.id))
        #expect(graph.has(edgeType: Notations.ADTree.EdgeTypes.andJunctorToDefense.id))
    }

    @Test func testADTreeNotationHasStyles() throws {
        var graph = VGraph()
        graph = try Notations.ADTree.addNotation(addTo: graph)

        let attackStyle: NodeStyleLayout = try graph.get(
            nodeType: Notations.ADTree.NodeTypes.attack,
            attribute: Attributes.Node.style
        )
        let defenseStyle: NodeStyleLayout = try graph.get(
            nodeType: Notations.ADTree.NodeTypes.defense,
            attribute: Attributes.Node.style
        )

        #expect(!attackStyle.asString.isEmpty)
        #expect(!defenseStyle.asString.isEmpty)
    }

    @Test func testADTreeColorConstants() {
        #expect(!Notations.ADTree.attackFill.hexString.isEmpty)
        #expect(!Notations.ADTree.attackBorder.hexString.isEmpty)
        #expect(!Notations.ADTree.attackText.hexString.isEmpty)
        #expect(!Notations.ADTree.defenseFill.hexString.isEmpty)
        #expect(!Notations.ADTree.defenseBorder.hexString.isEmpty)
        #expect(!Notations.ADTree.defenseText.hexString.isEmpty)

        #expect(Notations.ADTree.attackFill.hexString == "#fdeef1")
        #expect(Notations.ADTree.attackBorder.hexString == "#c83040")
        #expect(Notations.ADTree.attackText.hexString == "#7a0818")
        #expect(Notations.ADTree.defenseFill.hexString == "#ecfdf5")
        #expect(Notations.ADTree.defenseBorder.hexString == "#189858")
        #expect(Notations.ADTree.defenseText.hexString == "#085028")
    }

    @Test func testADTreeLayoutDirectionIsBottomToTop() throws {
        var graph = VGraph()
        graph = try Notations.ADTree.addNotation(addTo: graph)

        let layoutDirectionString: String = try graph.get(
            graphAttribute: Attributes.Group.layoutDirection
        )
        let layoutDirection = try LayoutDirection.fromString(layoutDirectionString)
        #expect(layoutDirection == .bottomToTop)
    }

    @Test func testCountermeasureEdgesAreDotted() throws {
        var graph = VGraph()
        graph = try Notations.ADTree.addNotation(addTo: graph)

        let defenseCountersStyle: Attributes.Edge.StyleType = try graph.get(
            edgeType: Notations.ADTree.EdgeTypes.defenseCountersAttack.id,
            attribute: Attributes.Edge.style
        )
        #expect(defenseCountersStyle == .dotted)

        let attackCountersStyle: Attributes.Edge.StyleType = try graph.get(
            edgeType: Notations.ADTree.EdgeTypes.attackCountersDefense.id,
            attribute: Attributes.Edge.style
        )
        #expect(attackCountersStyle == .dotted)
    }

    // MARK: - Data Confidentiality Example (from Kordy et al. 2014, Figure 1)

    @Test func testDataConfidentialityExample() throws {
        // Root is a Defense node (proponent = defender)
        var graph = VGraph()
        graph = try Notations.ADTree.addNotation(addTo: graph)

        // --- Defense nodes ---
        let dataConf = Node(string: "dataConf")
        graph = try graph.add(node: dataConf, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: dataConf,
            attribute: Attributes.Node.label.attribute("Data Confidentiality"))

        let networkSec = Node(string: "networkSec")
        graph = try graph.add(node: networkSec, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: networkSec,
            attribute: Attributes.Node.label.attribute("Network Security"))

        let physicalSec = Node(string: "physicalSec")
        graph = try graph.add(node: physicalSec, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: physicalSec,
            attribute: Attributes.Node.label.attribute("Physical Security"))

        let accessControl = Node(string: "accessControl")
        graph = try graph.add(node: accessControl, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: accessControl,
            attribute: Attributes.Node.label.attribute("Access Control"))

        let firewalls = Node(string: "firewalls")
        graph = try graph.add(node: firewalls, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: firewalls,
            attribute: Attributes.Node.label.attribute("Firewalls"))

        let ids = Node(string: "ids")
        graph = try graph.add(node: ids, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: ids,
            attribute: Attributes.Node.label.attribute("IDS"))

        let passwords = Node(string: "passwords")
        graph = try graph.add(node: passwords, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: passwords,
            attribute: Attributes.Node.label.attribute("Passwords"))

        let strongPasswords = Node(string: "strongPasswords")
        graph = try graph.add(node: strongPasswords, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: strongPasswords,
            attribute: Attributes.Node.label.attribute("Strong Passwords"))

        let lock1 = Node(string: "lock1")
        graph = try graph.add(node: lock1, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: lock1,
            attribute: Attributes.Node.label.attribute("Lock"))

        let reinforce1 = Node(string: "reinforce1")
        graph = try graph.add(node: reinforce1, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: reinforce1,
            attribute: Attributes.Node.label.attribute("Reinforce"))

        let lock2 = Node(string: "lock2")
        graph = try graph.add(node: lock2, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: lock2,
            attribute: Attributes.Node.label.attribute("Lock"))

        let reinforce2 = Node(string: "reinforce2")
        graph = try graph.add(node: reinforce2, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: reinforce2,
            attribute: Attributes.Node.label.attribute("Reinforce"))

        let screening = Node(string: "screening")
        graph = try graph.add(node: screening, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: screening,
            attribute: Attributes.Node.label.attribute("Screening"))

        let sensitivityTraining = Node(string: "sensitivityTraining")
        graph = try graph.add(node: sensitivityTraining, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: sensitivityTraining,
            attribute: Attributes.Node.label.attribute("Sensitivity Training"))

        let securityGuard = Node(string: "securityGuard")
        graph = try graph.add(node: securityGuard, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: securityGuard,
            attribute: Attributes.Node.label.attribute("Security Guard"))

        let videoCameras = Node(string: "videoCameras")
        graph = try graph.add(node: videoCameras, type: Notations.ADTree.NodeTypes.defense)
        graph = try graph.set(
            node: videoCameras,
            attribute: Attributes.Node.label.attribute("Video Cameras"))

        // --- Attack nodes ---
        let employeeAttack = Node(string: "employeeAttack")
        graph = try graph.add(node: employeeAttack, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: employeeAttack,
            attribute: Attributes.Node.label.attribute("Employee Attack"))

        let breakIn = Node(string: "breakIn")
        graph = try graph.add(node: breakIn, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: breakIn,
            attribute: Attributes.Node.label.attribute("Break In"))

        let corruption = Node(string: "corruption")
        graph = try graph.add(node: corruption, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: corruption,
            attribute: Attributes.Node.label.attribute("Corruption"))

        let socialEngineering = Node(string: "socialEngineering")
        graph = try graph.add(node: socialEngineering, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: socialEngineering,
            attribute: Attributes.Node.label.attribute("Social Engineering"))

        let dictionaryAttack = Node(string: "dictionaryAttack")
        graph = try graph.add(node: dictionaryAttack, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: dictionaryAttack,
            attribute: Attributes.Node.label.attribute("Dictionary Attack"))

        let strongPasswordAttacks = Node(string: "strongPasswordAttacks")
        graph = try graph.add(node: strongPasswordAttacks, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: strongPasswordAttacks,
            attribute: Attributes.Node.label.attribute("Strong Password Attacks"))

        let findNote = Node(string: "findNote")
        graph = try graph.add(node: findNote, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: findNote,
            attribute: Attributes.Node.label.attribute("Find Note"))

        let samePasswordDiffAccount = Node(string: "samePasswordDiffAccount")
        graph = try graph.add(node: samePasswordDiffAccount, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: samePasswordDiffAccount,
            attribute: Attributes.Node.label.attribute("Same Password, Different Account"))

        let backDoor = Node(string: "backDoor")
        graph = try graph.add(node: backDoor, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: backDoor,
            attribute: Attributes.Node.label.attribute("Back Door"))

        let fireEscape = Node(string: "fireEscape")
        graph = try graph.add(node: fireEscape, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: fireEscape,
            attribute: Attributes.Node.label.attribute("Fire Escape"))

        let window = Node(string: "window")
        graph = try graph.add(node: window, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: window,
            attribute: Attributes.Node.label.attribute("Window"))

        let door = Node(string: "door")
        graph = try graph.add(node: door, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: door,
            attribute: Attributes.Node.label.attribute("Door"))

        let windowEntry = Node(string: "windowEntry")
        graph = try graph.add(node: windowEntry, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: windowEntry,
            attribute: Attributes.Node.label.attribute("Window"))

        let defeatLock1 = Node(string: "defeatLock1")
        graph = try graph.add(node: defeatLock1, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: defeatLock1,
            attribute: Attributes.Node.label.attribute("Defeat Lock"))

        let forceOpen1 = Node(string: "forceOpen1")
        graph = try graph.add(node: forceOpen1, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: forceOpen1,
            attribute: Attributes.Node.label.attribute("Force Open"))

        let acquireKeys1 = Node(string: "acquireKeys1")
        graph = try graph.add(node: acquireKeys1, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: acquireKeys1,
            attribute: Attributes.Node.label.attribute("Acquire Keys"))

        let defeatLock2 = Node(string: "defeatLock2")
        graph = try graph.add(node: defeatLock2, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: defeatLock2,
            attribute: Attributes.Node.label.attribute("Defeat Lock"))

        let forceOpen2 = Node(string: "forceOpen2")
        graph = try graph.add(node: forceOpen2, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: forceOpen2,
            attribute: Attributes.Node.label.attribute("Force Open"))

        let acquireKeys2 = Node(string: "acquireKeys2")
        graph = try graph.add(node: acquireKeys2, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: acquireKeys2,
            attribute: Attributes.Node.label.attribute("Acquire Keys"))

        let defeatGuard = Node(string: "defeatGuard")
        graph = try graph.add(node: defeatGuard, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: defeatGuard,
            attribute: Attributes.Node.label.attribute("Defeat Guard"))

        let bribe = Node(string: "bribe")
        graph = try graph.add(node: bribe, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: bribe,
            attribute: Attributes.Node.label.attribute("Bribe"))

        let overpower = Node(string: "overpower")
        graph = try graph.add(node: overpower, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: overpower,
            attribute: Attributes.Node.label.attribute("Overpower"))

        let stealKeys = Node(string: "stealKeys")
        graph = try graph.add(node: stealKeys, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: stealKeys,
            attribute: Attributes.Node.label.attribute("Steal Keys"))

        let outnumber = Node(string: "outnumber")
        graph = try graph.add(node: outnumber, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: outnumber,
            attribute: Attributes.Node.label.attribute("Outnumber"))

        let useWeapons = Node(string: "useWeapons")
        graph = try graph.add(node: useWeapons, type: Notations.ADTree.NodeTypes.attack)
        graph = try graph.set(
            node: useWeapons,
            attribute: Attributes.Node.label.attribute("Use Weapons"))

        // --- AND junctors ---
        let andDataConf = Node(string: "andDataConf")
        graph = try graph.add(node: andDataConf, type: Notations.ADTree.NodeTypes.andJunctor)

        let andOverpower = Node(string: "andOverpower")
        graph = try graph.add(node: andOverpower, type: Notations.ADTree.NodeTypes.andJunctor)

        // --- Refinement edges (solid): Defense refines Defense ---
        // Data Confidentiality AND-refines into Network Security + Physical Security
        let e1 = Edge(id: "e1", from: networkSec, to: andDataConf)
        graph = try graph.add(edge: e1, edgeType: Notations.ADTree.EdgeTypes.defenseToAndJunctor)
        let e2 = Edge(id: "e2", from: physicalSec, to: andDataConf)
        graph = try graph.add(edge: e2, edgeType: Notations.ADTree.EdgeTypes.defenseToAndJunctor)
        let eAndDataConf = Edge(id: "eAndDataConf", from: andDataConf, to: dataConf)
        graph = try graph.add(edge: eAndDataConf, edgeType: Notations.ADTree.EdgeTypes.andJunctorToDefense)

        // Network Security AND-refines into Access Control, Firewalls, IDS
        let andNetworkSec = Node(string: "andNetworkSec")
        graph = try graph.add(node: andNetworkSec, type: Notations.ADTree.NodeTypes.andJunctor)

        let e3 = Edge(id: "e3", from: accessControl, to: andNetworkSec)
        graph = try graph.add(edge: e3, edgeType: Notations.ADTree.EdgeTypes.defenseToAndJunctor)
        let e4 = Edge(id: "e4", from: firewalls, to: andNetworkSec)
        graph = try graph.add(edge: e4, edgeType: Notations.ADTree.EdgeTypes.defenseToAndJunctor)
        let e5 = Edge(id: "e5", from: ids, to: andNetworkSec)
        graph = try graph.add(edge: e5, edgeType: Notations.ADTree.EdgeTypes.defenseToAndJunctor)
        let eAndNetworkSec = Edge(id: "eAndNetworkSec", from: andNetworkSec, to: networkSec)
        graph = try graph.add(edge: eAndNetworkSec, edgeType: Notations.ADTree.EdgeTypes.andJunctorToDefense)

        // Access Control -> Passwords
        let e6 = Edge(id: "e6", from: passwords, to: accessControl)
        graph = try graph.add(edge: e6, edgeType: Notations.ADTree.EdgeTypes.defenseRefinesDefense)

        // Strong Passwords counters Dictionary Attack (countermeasure)
        let e7 = Edge(id: "e7", from: strongPasswords, to: dictionaryAttack)
        graph = try graph.add(edge: e7, edgeType: Notations.ADTree.EdgeTypes.defenseCountersAttack)

        // Dictionary Attack counters Passwords (countermeasure)
        let e8 = Edge(id: "e8", from: dictionaryAttack, to: passwords)
        graph = try graph.add(edge: e8, edgeType: Notations.ADTree.EdgeTypes.attackCountersDefense)

        // Strong Password Attacks counters Strong Passwords
        let e9 = Edge(id: "e9", from: strongPasswordAttacks, to: strongPasswords)
        graph = try graph.add(edge: e9, edgeType: Notations.ADTree.EdgeTypes.attackCountersDefense)

        // Strong Password Attacks OR-refines into Find Note, Same Password Different Account
        let e10 = Edge(id: "e10", from: findNote, to: strongPasswordAttacks)
        graph = try graph.add(edge: e10, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)
        let e11 = Edge(id: "e11", from: samePasswordDiffAccount, to: strongPasswordAttacks)
        graph = try graph.add(edge: e11, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)

        // Break In counters Physical Security (countermeasure)
        let e12 = Edge(id: "e12", from: breakIn, to: physicalSec)
        graph = try graph.add(edge: e12, edgeType: Notations.ADTree.EdgeTypes.attackCountersDefense)

        // Break In OR-refines into Back Door, Fire Escape, Window
        let e13 = Edge(id: "e13", from: backDoor, to: breakIn)
        graph = try graph.add(edge: e13, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)
        let e14 = Edge(id: "e14", from: fireEscape, to: breakIn)
        graph = try graph.add(edge: e14, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)
        let e15 = Edge(id: "e15", from: window, to: breakIn)
        graph = try graph.add(edge: e15, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)

        // Lock counters Back Door
        let e16 = Edge(id: "e16", from: lock1, to: backDoor)
        graph = try graph.add(edge: e16, edgeType: Notations.ADTree.EdgeTypes.defenseCountersAttack)

        // Fire Escape OR-refines into Door, Window
        let e17 = Edge(id: "e17", from: door, to: fireEscape)
        graph = try graph.add(edge: e17, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)
        let e18 = Edge(id: "e18", from: windowEntry, to: fireEscape)
        graph = try graph.add(edge: e18, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)

        // Lock counters Door
        let e19 = Edge(id: "e19", from: lock2, to: door)
        graph = try graph.add(edge: e19, edgeType: Notations.ADTree.EdgeTypes.defenseCountersAttack)

        // Reinforce counters Window
        let e20 = Edge(id: "e20", from: reinforce1, to: window)
        graph = try graph.add(edge: e20, edgeType: Notations.ADTree.EdgeTypes.defenseCountersAttack)

        // Reinforce counters Window entry
        let e21 = Edge(id: "e21", from: reinforce2, to: windowEntry)
        graph = try graph.add(edge: e21, edgeType: Notations.ADTree.EdgeTypes.defenseCountersAttack)

        // Defeat Lock counters Lock (back door)
        let e22 = Edge(id: "e22", from: defeatLock1, to: lock1)
        graph = try graph.add(edge: e22, edgeType: Notations.ADTree.EdgeTypes.attackCountersDefense)

        // Defeat Lock OR-refines into Force Open, Acquire Keys
        let e23 = Edge(id: "e23", from: forceOpen1, to: defeatLock1)
        graph = try graph.add(edge: e23, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)
        let e24 = Edge(id: "e24", from: acquireKeys1, to: defeatLock1)
        graph = try graph.add(edge: e24, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)

        // Defeat Lock counters Lock (door)
        let e25 = Edge(id: "e25", from: defeatLock2, to: lock2)
        graph = try graph.add(edge: e25, edgeType: Notations.ADTree.EdgeTypes.attackCountersDefense)

        // Defeat Lock 2 OR-refines into Force Open 2, Acquire Keys 2
        let e26 = Edge(id: "e26", from: forceOpen2, to: defeatLock2)
        graph = try graph.add(edge: e26, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)
        let e27 = Edge(id: "e27", from: acquireKeys2, to: defeatLock2)
        graph = try graph.add(edge: e27, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)

        // Security Guard counters Break In
        let e28 = Edge(id: "e28", from: securityGuard, to: breakIn)
        graph = try graph.add(edge: e28, edgeType: Notations.ADTree.EdgeTypes.defenseCountersAttack)

        // Defeat Guard counters Security Guard
        let e29 = Edge(id: "e29", from: defeatGuard, to: securityGuard)
        graph = try graph.add(edge: e29, edgeType: Notations.ADTree.EdgeTypes.attackCountersDefense)

        // Defeat Guard OR-refines into Bribe, Overpower, Steal Keys
        let e30 = Edge(id: "e30", from: bribe, to: defeatGuard)
        graph = try graph.add(edge: e30, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)
        let e31 = Edge(id: "e31", from: overpower, to: defeatGuard)
        graph = try graph.add(edge: e31, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)
        let e32 = Edge(id: "e32", from: stealKeys, to: defeatGuard)
        graph = try graph.add(edge: e32, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)

        // Video Cameras counters Defeat Guard
        let e33 = Edge(id: "e33", from: videoCameras, to: defeatGuard)
        graph = try graph.add(edge: e33, edgeType: Notations.ADTree.EdgeTypes.defenseCountersAttack)

        // Overpower AND-refines into Outnumber + Use Weapons
        let e34 = Edge(id: "e34", from: outnumber, to: andOverpower)
        graph = try graph.add(edge: e34, edgeType: Notations.ADTree.EdgeTypes.attackToAndJunctor)
        let e35 = Edge(id: "e35", from: useWeapons, to: andOverpower)
        graph = try graph.add(edge: e35, edgeType: Notations.ADTree.EdgeTypes.attackToAndJunctor)
        let eAndOverpower = Edge(id: "eAndOverpower", from: andOverpower, to: overpower)
        graph = try graph.add(edge: eAndOverpower, edgeType: Notations.ADTree.EdgeTypes.andJunctorToAttack)

        // Employee Attack counters Data Confidentiality (countermeasure)
        let e36 = Edge(id: "e36", from: employeeAttack, to: dataConf)
        graph = try graph.add(edge: e36, edgeType: Notations.ADTree.EdgeTypes.attackCountersDefense)

        // Employee Attack OR-refines into Corruption, Social Engineering
        let e37 = Edge(id: "e37", from: corruption, to: employeeAttack)
        graph = try graph.add(edge: e37, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)
        let e38 = Edge(id: "e38", from: socialEngineering, to: employeeAttack)
        graph = try graph.add(edge: e38, edgeType: Notations.ADTree.EdgeTypes.attackRefinesAttack)

        // Screening counters Corruption
        let e39 = Edge(id: "e39", from: screening, to: corruption)
        graph = try graph.add(edge: e39, edgeType: Notations.ADTree.EdgeTypes.defenseCountersAttack)

        // Sensitivity Training counters Social Engineering
        let e40 = Edge(id: "e40", from: sensitivityTraining, to: socialEngineering)
        graph = try graph.add(edge: e40, edgeType: Notations.ADTree.EdgeTypes.defenseCountersAttack)

        #expect(graph.nodes.count == 44)

        #expect((try graph.nodeType(for: dataConf)) == Notations.ADTree.NodeTypes.defense)
        #expect((try graph.nodeType(for: breakIn)) == Notations.ADTree.NodeTypes.attack)
        #expect((try graph.nodeType(for: andDataConf)) == Notations.ADTree.NodeTypes.andJunctor)
        #expect((try graph.nodeType(for: andNetworkSec)) == Notations.ADTree.NodeTypes.andJunctor)
        #expect((try graph.nodeType(for: andOverpower)) == Notations.ADTree.NodeTypes.andJunctor)

        let dataConfLabel: String = try graph.get(node: dataConf, attribute: Attributes.Node.label)
        #expect(dataConfLabel == "Data Confidentiality")

        let breakInLabel: String = try graph.get(node: breakIn, attribute: Attributes.Node.label)
        #expect(breakInLabel == "Break In")
    }

    // MARK: - Parser Tests

    @Test func testADTreeGraphFromParser() throws {
        let adTreeInput = """
            vgraph dataConfidentiality: ADTree "Data Confidentiality" {
                node dataConf: Defense "Data Confidentiality";
                node networkSec: Defense "Network Security";
                node physicalSec: Defense "Physical Security";
                node breakIn: Attack "Break In";
                node backDoor: Attack "Back Door";
                node fireEscape: Attack "Fire Escape";
                node lock1: Defense "Lock";
                node defeatLock: Attack "Defeat Lock";
                node forceOpen: Attack "Force Open";
                node acquireKeys: Attack "Acquire Keys";
                node andDataConf: AndJunctor;

                edge networkSec -> andDataConf: defense_to_and_junctor;
                edge physicalSec -> andDataConf: defense_to_and_junctor;
                edge andDataConf -> dataConf: and_junctor_to_defense;
                edge breakIn -> physicalSec: attack_counters_defense;
                edge backDoor -> breakIn: attack_refines_attack;
                edge fireEscape -> breakIn: attack_refines_attack;
                edge lock1 -> backDoor: defense_counters_attack;
                edge defeatLock -> lock1: attack_counters_defense;
                edge forceOpen -> defeatLock: attack_refines_attack;
                edge acquireKeys -> defeatLock: attack_refines_attack;
            }
            """

        let parser = VGraphParser(logger: NoOpLogger())
        let graph = try parser.parse(source: adTreeInput)

        let id: String = try graph.get(graphAttribute: Attributes.Group.Id)
        #expect(id == "dataConfidentiality")
        let label: String = try graph.get(graphAttribute: Attributes.Group.label)
        #expect(label == "Data Confidentiality")

        // Verify counts: 4 defense + 6 attack + 1 AND junctor = 11 nodes, 10 edges
        #expect(graph.nodes.count == 11)
        #expect(graph.edges.count == 10)

        let dataConf = Node(string: "dataConf")
        let breakIn = Node(string: "breakIn")
        let lock1 = Node(string: "lock1")

        #expect((try graph.nodeType(for: dataConf)) == Notations.ADTree.NodeTypes.defense)
        #expect((try graph.nodeType(for: breakIn)) == Notations.ADTree.NodeTypes.attack)
        #expect((try graph.nodeType(for: lock1)) == Notations.ADTree.NodeTypes.defense)

        let dataConfLabel: String = try graph.get(node: dataConf, attribute: Attributes.Node.label)
        #expect(dataConfLabel == "Data Confidentiality")

        let edges = graph.edges
        let breakInToPhysical = edges.first { $0.from == breakIn && $0.to == Node(string: "physicalSec") }
        #expect(breakInToPhysical != nil)
        #expect(
            (try graph.edgeType(for: breakInToPhysical!.id))
                == Notations.ADTree.EdgeTypes.attackCountersDefense)
    }

}
