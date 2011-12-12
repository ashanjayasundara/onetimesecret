

class Onetime::Customer < Familia::HashKey
  @values = Familia::SortedSet.new name.to_s.downcase.gsub('::', Familia.delim).to_sym, :db => 6
  class << self
    attr_reader :values
    def add cust
      self.values.add OT.now.to_i, cust.identifier
    end
    def all
      self.values.revrangeraw(0, -1).collect { |identifier| load(identifier) }
    end
    def recent duration=30.days
      spoint, epoint = OT.now.to_i-duration, OT.now.to_i
      self.values.rangebyscoreraw(spoint, epoint).collect { |identifier| load(identifier) }
    end
  end
  include Onetime::Models::RedisHash
  include Onetime::Models::Passphrase
  def initialize custid=:anon
    @custid = custid  # if we use accessor methods it will sync to redis.
    super name, :db => 6
  end
  def identifier 
    @custid
  end
  def apitoken? guess
    self.apitoken.to_s == guess.to_s
  end
  def regenerate_apitoken
    self.apitoken = [OT.instance, OT.now.to_f, :apikey, custid].gibbler
  end
  def get_persistent_value sess, n
    (anonymous? ? sess : self)[n]
  end
  def set_persistent_value sess, n, v 
    (anonymous? ? sess : self)[n] = v
  end
  def external_identifier
    if anonymous?
      raise OT::Problem, "Anonymous customer has no external identifier"
    end
    elements = [custid]
    @external_identifier ||= elements.gibbler #.base(36)
    @external_identifier
  end
  def anonymous?
    custid.to_s == 'anon'
  end
  def email
    @custid
  end
  def role
    self.get_value(:role) || 'customer'
  end
  def role? guess
    role.to_s == guess.to_s
  end
  def verified?
    verified.to_s == "verified"
  end
  def metadata_list
    if @metadata_list.nil?
      el = [prefix, identifier, :metadata]
      el.unshift Familia.apiversion unless Familia.apiversion.nil?
      @metadata_list = Familia::SortedSet.new Familia.join(el)
    end
    @metadata_list
  end
  def metadata
    metadata_list.revmembers.collect { |key| OT::Metadata.load key }.compact
  end
  def add_metadata s
    metadata_list.add OT.now.to_i, s.key
  end
  class << self
    def anonymous
      cust = new
    end
    def exists? custid
      cust = new custid
      cust.exists?
    end
    def load custid
      cust = new custid
      cust.exists? ? cust : nil
    end
    def create custid, email=nil
      cust = new custid
      # force the storing of the fields to redis
      cust.custid = custid
      cust.save
      add cust
      cust
    end
  end
end