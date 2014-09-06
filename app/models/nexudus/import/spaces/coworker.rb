class Nexudus::Import::Spaces::Coworker
  include Singleton

  attr_reader :client

  def initialize
    @client = Nexudus::Import::Spaces::CoworkerClient.new
  end

  # Updates members with data from the Nexudus API
  def update
    if last_updated_at
      params = {
        'from_Coworker_UpdatedOn' => last_updated_at.iso8601
      }
    else
      params = nil
    end

    # The api is paginated, so we need to loop through all pages
    complete = false
    until complete
      # Fetch coworkers
      response = @client.coworkers(params)

      # Import coworkers
      import response['Records']

      # Handle pagination
      currentPage = response['CurrentPage']
      totalPages = response['TotalPages']

      if currentPage == totalPages
        complete = true
      else
        nextPage = currentPage += 1
        { 'page' => nextPage }.merge! params || {}
      end
    end
  end

  private

  # Retrive timestamp for last updated member
  def last_updated_at
    if Member.count > 0
      Member
        .select(:nexudus_updated_at)
        .order(nexudus_updated_at: :desc)
        .first
        .nexudus_updated_at
    else
      nil
    end
  end

  # Save given coworkers to the database
  def import coworkers
    coworkers.each do |coworker|
      member = Member.find_or_initialize_by nexudus_id: coworker['UniqueId']

      member.first_name, member.last_name = coworker['FullName'].split(" ", 2)
      member.email                        = coworker['Email']
      member.nexudus_user_id              = coworker['UserID']
      member.nexudus_updated_at           = coworker['UpdatedOn']
      member.nexudus_created_at           = coworker['CreatedOn']
      #member.membership_level             = coworker['']
      #member.membership_renewal_date      = coworker['']
      #member.membership_status            = coworker['']
      member.active                       = coworker['Active']

      member.save!
    end
  end
end
