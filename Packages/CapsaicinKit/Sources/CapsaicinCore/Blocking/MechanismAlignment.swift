public enum MechanismAlignment {
    /// - Parameter observed: 仕組みごとの、適用していると見込める状態。キーがなければ分からない（前のプロセスから残ったもの）。
    ///     disablesleep は、最後に読んだ `SleepDisabled` を持つ。
    public static func misalignments(
        targets: Set<Mechanism>,
        observed: [Mechanism: Bool],
        ownsSleepDisabled: Bool,
        controllable: Set<Mechanism>,
    ) -> Misalignments {
        var result: Misalignments = [:]
        for mechanism in controllable {
            let wanted = targets.contains(mechanism)
            if mechanism == .systemSleepDisabled, !wanted {
                // 外部のものには触れないので、自分が立てたものが残っているときだけ合っていない。
                if ownsSleepDisabled {
                    result[mechanism] = .leftApplied
                }
                continue
            }
            if observed[mechanism] != wanted {
                result[mechanism] = wanted ? .notApplied : .leftApplied
            }
        }
        return result
    }
}
