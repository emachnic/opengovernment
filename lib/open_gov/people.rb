module OpenGov
  class People < Resources
    class << self
      def import!
        State.loadable.each do |state|
          import_one(state)
        end
      end

      def import_one(state)
        GovKit::FiftyStates::Legislator.search(:state => state.abbrev).each do |fs_person|
          unless person = Person.find_by_fiftystates_id(fs_person.leg_id)
            person = Person.new(:fiftystates_id => fs_person.leg_id)
          end

          person.update_attributes!(
            :first_name => fs_person.first_name,
            :last_name => fs_person.last_name,
            :votesmart_id => fs_person.votesmart_id,
            :nimsp_candidate_id => fs_person.nimsp_candidate_id,
            :middle_name => fs_person.middle_name,
            :suffix => fs_person.suffix,
            :updated_at => fs_person.updated_at
          )

          person.save!

          fs_person.roles.each do |fs_role|

            legislature = state.legislature
            session = Session.find_by_legislature_id_and_name(state.legislature, fs_role.session)

            case fs_role[:type]
              when GovKit::FiftyStates::ROLE_MEMBER :
                case fs_role.chamber
                  when GovKit::FiftyStates::CHAMBER_UPPER
                    chamber = legislature.upper_chamber
                  when GovKit::FiftyStates::CHAMBER_LOWER
                    chamber = legislature.lower_chamber
                end

                district = chamber.districts.numbered(fs_role.district.to_s).first

                role = Role.find_or_initialize_by_district_id_and_chamber_id(district.id, chamber.id)
                role.update_attributes!(
                  :person => person,
                  :session => session,
                  :start_date => valid_date!(fs_role.start_date),
                  :end_date => valid_date!(fs_role.end_date),
                  :party => fs_role.party
                )
              when GovKit::FiftyStates::ROLE_COMMITTEE_MEMBER :
                # TODO: This lookup is awkward, and there are actually
                # committees that Votesmart doesn't have and that fiftystates has,
                # and we should be adding those when we see them. Their
                # votesmart_committee_id will be nil.
                if committee = Committee.find_by_votesmart_id(fs_role.votesmart_committee_id) || Committee.find_by_name(fs_role.committee)
                  committee_membership = CommitteeMembership.find_or_create_by_person_id_and_session_id_and_committee_id(person.id, session.id, committee.id)
                end

            end
          end
        end
      end
    end
  end
end