function result = iscolumnvector(obj)
import tilerUtils.yaml.*;
result = isvector(obj) && size(obj,2) == 1 && size(obj,1) > 1 && ndims(obj) == 2;
end