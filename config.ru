#\ -p 80

use Rack::Static, :urls => ["/assets"]

require "./airserve"

run Cuba
