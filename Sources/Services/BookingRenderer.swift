import DiscordBM
import Foundation

enum BookingRenderer {
    static func creationModal(
        kind: BookingCreationForm.Kind,
        worlds: [FoundryWorld],
        defaultEventBookingTime: TimeInterval,
        localization: LocalizationContext,
        dateTime: Date? = nil,
        campaignRoleID: RoleSnowflake? = nil,
        sourcePollID: String? = nil,
        sourceCandidateID: UUID? = nil
    ) -> Payloads.InteractionResponse {
        let maximumWorldOptions = kind == .event ? 24 : 25
        let worldOptions = (kind == .event ? [
            Interaction.ActionRow.StringSelectMenu.Option(
                label: localization.string("modal.no_foundry_world", table: "Booking"),
                value: BookingCreationForm.noFoundryWorldValue,
                description: localization.string("modal.external_session_description", table: "Booking"),
                default: true
            )
        ] : []) + worlds.filter { $0.id.count <= 100 }.prefix(maximumWorldOptions).map {
            .init(label: String($0.title.prefix(100)), value: $0.id, description: String($0.id.prefix(100)))
        }
        let worldSelect = Interaction.ModalComponent.label(.init(
            label: localization.string("modal.foundry_world", table: "Booking"),
            component: .stringSelect(.init(
                custom_id: BookingCreationForm.worldComponentID,
                options: worldOptions,
                placeholder: kind == .event
                    ? localization.string("modal.no_foundry_world", table: "Booking")
                    : localization.string("modal.select_world", table: "Booking"),
                min_values: 1,
                max_values: 1,
                required: true
            ))
        ))

        switch kind {
        case .reservation:
            return .modal(.init(
                custom_id: modalID(kind: kind, sourcePollID: sourcePollID, sourceCandidateID: sourceCandidateID),
                title: localization.string("modal.create_reservation", table: "Booking"),
                componentsV2: [
                    worldSelect,
                    .label(.init(
                        label: localization.string("modal.reservation_date", table: "Booking"),
                        description: localization.string("modal.date_format_description", table: "Booking"),
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
                title: localization.string("modal.create_event_booking", table: "Booking"),
                componentsV2: [
                    worldSelect,
                    .label(.init(
                        label: localization.string("modal.event_date_time", table: "Booking"),
                        description: localization.string(
                            "modal.date_time_format_description",
                            table: "Booking",
                            defaultTime
                        ),
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
                        label: localization.string("modal.voice_channel", table: "Booking"),
                        component: .channelSelect(.init(
                            custom_id: BookingCreationForm.locationID,
                            channel_types: [.guildVoice],
                            placeholder: localization.string("modal.select_voice_channel", table: "Booking"),
                            min_values: 0,
                            max_values: 1,
                            required: false
                        ))
                    )),
                    .label(.init(
                        label: localization.string("modal.session_topic", table: "Booking"),
                        component: .textInput(.init(
                            custom_id: BookingCreationForm.topicID,
                            style: .short,
                            max_length: 100,
                            required: true,
                            placeholder: localization.string("modal.session_topic_placeholder", table: "Booking")
                        ))
                    )),
                    .label(.init(
                        label: localization.string("modal.campaign_role", table: "Booking"),
                        component: .roleSelect(.init(
                            custom_id: BookingCreationForm.roleID,
                            placeholder: localization.string("modal.select_campaign_role", table: "Booking"),
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
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }()
}
