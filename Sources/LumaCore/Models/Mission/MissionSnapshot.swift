import Foundation

public struct MissionSnapshot: Sendable {
    public var missions: [Mission]
    public var turns: [MissionTurn]
    public var actions: [MissionAction]
    public var findings: [MissionFinding]
    public var evidence: [MissionEvidence]

    public init(
        missions: [Mission] = [],
        turns: [MissionTurn] = [],
        actions: [MissionAction] = [],
        findings: [MissionFinding] = [],
        evidence: [MissionEvidence] = []
    ) {
        self.missions = missions
        self.turns = turns
        self.actions = actions
        self.findings = findings
        self.evidence = evidence
    }
}
