import DiscordBM
import Logging

struct BookingModalHandler {
    let client: any DiscordClient
    let guildRegistry: GuildRegistry
    private let logger = Logger(label: String(describing: Self.self))

    func handle(_ modal: Interaction.ModalSubmit, interaction: Interaction) async throws {
        try await client.createInteractionResponse(
            id: interaction.id,
            token: interaction.token,
            payload: .deferredChannelMessageWithSource()
        ).guardSuccess()

        do {
            guard let guildID = interaction.guild_id, let member = interaction.member, let user = member.user else {
                throw DiscordCommandError.noGuild
            }
            let context = try await guildRegistry.context(for: guildID)
            guard context.permissions.permissionsLevel(of: user.id, roles: member.roles) >= .dungeonMaster else {
                throw DiscordCommandError.unauthorized(requiredLevel: .dungeonMaster)
            }

            let form = try BookingCreationForm(from: modal, defaultEventBookingTime: context.config.defaultEventBookingTime)
            if form.kind == .reservation || form.worldID != nil {
                guard context.config.foundryFeaturesEnabled else {
                    throw DiscordCommandError.foundryFeaturesDisabled
                }
                let worlds = try await PterodactylAPI.shared.worlds()
                guard worlds.contains(where: { $0.id == form.worldID }) else {
                    throw DiscordCommandError.worldDoesNotExist(worldID: form.worldID ?? "")
                }
            }
            guard await context.bookings.booking(at: form.date) == nil else {
                throw DiscordCommandError.bookingAlreadyExists(atDate: form.date)
            }

            let booking: any Booking
            var warning: String?
            switch form.kind {
            case .reservation:
                guard let worldID = form.worldID else { throw DiscordCommandError.invalidBookingForm }
                booking = ReservationBooking(
                    date: form.date,
                    author: user.id,
                    worldID: worldID,
                    configuration: context.config
                )
            case .event:
                guard let campaignRoleID = form.campaignRoleID, let topic = form.topic else {
                    throw DiscordCommandError.invalidBookingForm
                }
                booking = EventBooking(
                    date: form.date,
                    author: user.id,
                    worldID: form.worldID,
                    campaignRoleSnowflake: campaignRoleID,
                    location: form.locationID,
                    topic: topic,
                    configuration: context.config
                )
                if booking.worldID != nil, booking.date > booking.bookingIntervalEndDate(using: context.config) {
                    let start = DiscordUtils.timestamp(date: booking.bookingIntervalStartDate(using: context.config), style: .shortDateTime)
                    let end = DiscordUtils.timestamp(date: booking.bookingIntervalEndDate(using: context.config), style: .shortDateTime)
                    warning = "\nThe world will be locked from \(start) to \(end).\n" +
                        "**Warning**: With the current configuration settings, the world will be unlocked before the event starts."
                }
            }

            try await context.bookings.createBookingIfAvailable(booking)
            if let sourcePollID = form.sourcePollID,
               let sourceCandidateID = form.sourceCandidateID,
               let poll = await context.datePolls.markFinalizedCandidateBooked(
                   pollID: sourcePollID,
                   candidateID: sourceCandidateID
               ),
               let messageID = poll.messageID {
                do {
                    try await client.updateMessage(
                        channelId: poll.channelID,
                        messageId: messageID,
                        payload: DatePollRenderer.messagePayload(for: poll, foundryFeaturesEnabled: context.config.foundryFeaturesEnabled)
                    ).guardSuccess()
                } catch {
                    logger.warning("Failed to remove booked date-poll candidate control: \(error)")
                }
            }
            try await client.respond(
                token: interaction.token,
                payload: .init(
                    content: "Booking created successfully.\(warning ?? "")",
                    embeds: [Utils.createBookingEmbed(for: booking)]
                )
            )
        } catch {
            if let commandError = error as? DiscordCommandError, case .invalidBookingForm = commandError {
                logger.warning("Invalid booking form components: \(modalComponentSummary(modal))")
            }
            logger.warning("Failed to create booking from modal: \(error)")
            try await client.respond(token: interaction.token, message: error.localizedDescription)
        }
    }

    private func modalComponentSummary(_ modal: Interaction.ModalSubmit) -> String {
        let components = modal.componentsV2 ?? []
        return components.compactMap { component in
            guard case let .label(label) = component, let customID = label.component.customId else {
                return nil
            }
            switch label.component {
            case let .stringSelect(select):
                return "\(customID)=stringSelect(values: \(select.values?.count ?? 0))"
            case let .roleSelect(select):
                return "\(customID)=roleSelect(values: \(select.values?.count ?? 0))"
            case let .channelSelect(select):
                return "\(customID)=channelSelect(values: \(select.values?.count ?? 0))"
            case .textInput:
                return "\(customID)=textInput"
            default:
                return "\(customID)=other"
            }
        }.joined(separator: ", ")
    }
}
