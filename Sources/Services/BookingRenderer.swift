import DiscordBM
import Foundation

enum BookingRenderer {
    static func creationModal(
        kind: BookingCreationForm.Kind,
        worlds: [FoundryWorld],
        defaultEventBookingTime: TimeInterval,
        dateTime: Date? = nil,
        campaignRoleID: RoleSnowflake? = nil,
        sourcePollID: String? = nil,
        sourceCandidateID: UUID? = nil
    ) -> Payloads.InteractionResponse {
        let maximumWorldOptions = kind == .event ? 24 : 25
        let worldOptions = (kind == .event ? [
            Interaction.ActionRow.StringSelectMenu.Option(
                label: "No Foundry world",
                value: BookingCreationForm.noFoundryWorldValue,
                description: "External or in-person session",
                default: true
            )
        ] : []) + worlds.filter { $0.id.count <= 100 }.prefix(maximumWorldOptions).map {
            .init(label: String($0.title.prefix(100)), value: $0.id, description: String($0.id.prefix(100)))
        }
        let worldSelect = Interaction.ModalComponent.label(.init(
            label: "Foundry world",
            component: .stringSelect(.init(
                custom_id: BookingCreationForm.worldComponentID,
                options: worldOptions,
                placeholder: kind == .event ? "No Foundry world" : "Select world",
                min_values: 1,
                max_values: 1,
                required: true
            ))
        ))

        switch kind {
        case .reservation:
            return .modal(.init(
                custom_id: modalID(kind: kind, sourcePollID: sourcePollID, sourceCandidateID: sourceCandidateID),
                title: "Create reservation",
                componentsV2: [
                    worldSelect,
                    .label(.init(
                        label: "Reservation date",
                        description: "Format: DD.MM.YYYY",
                        component: .textInput(.init(
                            custom_id: BookingCreationForm.dateID,
                            style: .short,
                            max_length: 10,
                            required: true,
                            placeholder: "31.12.2026"
                        ))
                    )),
                ]
            ))

        case .event:
            let defaultTime = Utils.timeString(for: defaultEventBookingTime)
            return .modal(.init(
                custom_id: modalID(kind: kind, sourcePollID: sourcePollID, sourceCandidateID: sourceCandidateID),
                title: "Create event booking",
                componentsV2: [
                    worldSelect,
                    .label(.init(
                        label: "Event date and time",
                        description: "Format: DD.MM.YYYY [HH:MM]; missing time defaults to \(defaultTime)",
                        component: .textInput(.init(
                            custom_id: BookingCreationForm.dateTimeID,
                            style: .short,
                            max_length: 16,
                            required: true,
                            value: dateTime.map { dateTimeFormatter.string(from: $0) },
                            placeholder: "31.12.2026 \(defaultTime)"
                        ))
                    )),
                    .label(.init(
                        label: "Voice channel",
                        component: .channelSelect(.init(
                            custom_id: BookingCreationForm.locationID,
                            channel_types: [.guildVoice],
                            placeholder: "Select voice channel",
                            min_values: 0,
                            max_values: 1,
                            required: false
                        ))
                    )),
                    .label(.init(
                        label: "Session topic",
                        component: .textInput(.init(
                            custom_id: BookingCreationForm.topicID,
                            style: .short,
                            max_length: 100,
                            required: true,
                            placeholder: "Session 12"
                        ))
                    )),
                    .label(.init(
                        label: "Campaign role",
                        component: .roleSelect(.init(
                            custom_id: BookingCreationForm.roleID,
                            placeholder: "Select campaign role",
                            default_values: campaignRoleID.map { [.init(id: $0)] },
                            min_values: campaignRoleID == nil ? 0 : 1,
                            max_values: 1,
                            required: campaignRoleID != nil
                        ))
                    )),
                ]
            ))
        }
    }

    private static func modalID(
        kind: BookingCreationForm.Kind,
        sourcePollID: String?,
        sourceCandidateID: UUID?
    ) -> String {
        guard let sourcePollID, let sourceCandidateID else {
            return BookingCreationForm.modalPrefix + kind.rawValue
        }
        return "\(BookingCreationForm.modalPrefix)\(kind.rawValue):\(sourcePollID):\(sourceCandidateID.uuidString)"
    }

    private static let dateTimeFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }()
}
