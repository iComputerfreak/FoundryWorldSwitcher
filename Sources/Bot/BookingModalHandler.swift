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

        var localization = LocalizationContext.english
        do {
            guard let guildID = interaction.guild_id else {
                throw DiscordCommandError.noGuild
            }
            let context = try await guildRegistry.context(for: guildID)
            localization = context.config.localization
            guard let member = interaction.member, let user = member.user else {
                throw DiscordCommandError.noUser
            }
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
                    warning = localization.string("booking.world_lock_warning", table: "Bot", start, end)
                }
            }

            let sourcePoll: DatePoll?
            if let sourcePollID = form.sourcePollID,
               let sourceCandidateID = form.sourceCandidateID {
                sourcePoll = try await context.datePolls.claimFinalizedCandidateBooking(
                    pollID: sourcePollID,
                    candidateID: sourceCandidateID,
                    bookingID: booking.id,
                    bookingDate: booking.date
                )
                do {
                    try await context.bookings.createBookingIfAvailable(booking)
                } catch {
                    await context.datePolls.releaseFinalizedCandidateBooking(
                        pollID: sourcePollID,
                        candidateID: sourceCandidateID,
                        bookingID: booking.id
                    )
                    throw error
                }
            } else {
                sourcePoll = nil
                try await context.bookings.createBookingIfAvailable(booking)
            }
            if let sourcePoll {
                await DatePollMessageSynchronizer.synchronize(
                    [sourcePoll],
                    datePolls: context.datePolls,
                    client: client
                )
            }
            try await client.respond(
                token: interaction.token,
                payload: .init(
                    content: localization.string("booking.created", table: "Bot") + (warning ?? ""),
                    embeds: [Utils.createBookingEmbed(for: booking, localization: localization)]
                )
            )
        } catch {
            if let commandError = error as? DiscordCommandError, case .invalidBookingForm = commandError {
                logger.warning("Invalid booking form components: \(modalComponentSummary(modal))")
            }
            logger.warning("Failed to create booking from modal: \(error)")
            try await client.respond(
                token: interaction.token,
                message: UserFacingErrorRenderer.message(for: error, localization: localization)
            )
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
