#wrapper taken from: https://gist.github.com/stephan-nordnes-eriksen/6c9c56f63f36d5d100b://gist.github.com/stephan-nordnes-eriksen/6c9c56f63f36d5d100b2 
class DBM_Wrapper

  def initialize(file_name)
      # @store = DBM.open("testDBM", 666, DBM::WRCREAT)
      @store = DBM.new(file_name)
  end

  def []=(key,val)
      @store[key] = val
  end

  def [](key)
      @store[key]
  end

  def each(&block)
    @store.each(&block)
  end

  def values
      @store.values
  end

  def keys
      @store.keys
  end

  def delete(key)
      @store.delete(key)
  end

  def stop
      @store.close unless @store.closed?
  end

  def destroy
      stop
      FileUtils.rm("testDBM.db")
  end

  def sync_lock
  end
end
