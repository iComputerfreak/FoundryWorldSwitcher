import DiscordBM

enum BookingRenderer {
    static func creationModal(
        kind: BookingCreationForm.Kind,
        worlds: [FoundryWorld]
    ) -> Payloads.InteractionResponse {
        let worldSelect = Interaction.ModalComponent.label(.init(
            label: "Foundry world",
            component: .stringSelect(.init(
                custom_id: BookingCreationForm.worldID,
                options: worlds.map {
                    .init(label: String($0.title.prefix(100)), value: $0.id, description: String($0.id.prefix(100)))
                },
                placeholder: "Select world",
                min_values: 1,
                max_values: 1,
                required: true
            ))
        ))

        switch kind {
        case .reservation:
            return .modal(.init(
                custom_id: BookingCreationForm.modalPrefix + kind.rawValue,
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
            return .modal(.init(
                custom_id: BookingCreationForm.modalPrefix + kind.rawValue,
                title: "Create event booking",
                componentsV2: [
                    worldSelect,
                    .label(.init(
                        label: "Event date and time",
                        description: "Format: DD.MM.YYYY HH:MM",
                        component: .textInput(.init(
                            custom_id: BookingCreationForm.dateTimeID,
                            style: .short,
                            max_length: 16,
                            required: true,
                            placeholder: "31.12.2026 19:00"
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
                            min_values: 0,
                            max_values: 1,
                            required: false
                        ))
                    )),
                ]
            ))
        }
    }
}
