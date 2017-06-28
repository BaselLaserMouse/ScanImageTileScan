function [tilePosArray,tileIndexArray] = tilePattern(obj,quiet)
    % Calculate the tile pattern for imaging
    % 
    % function [tilePosArray,tileIndexArray] = tilePattern(obj,quiet)
    % 
    %
    % Note
    % We define obj.NumTiles.Y and obj.NumTiles.X with respect to the user's
    % view standing in front of the scope. 
    %
    % Outputs
    % tilePosArray - One row per position. first column is X stage positions 
    % second Y stage positions. These are in mm.
    % tileIndexArray - The index of each tile on the grid. Columns as in tilePosArray.
    %
    % 
    %

    if nargin<2
        quiet=false;
    end

    % The following line is a bit horrible (TODO: fix this schema) 
    % What it's doing is calling recipe.recordScannerSettings to populate the imaging parameter
    % fields such as recipe.ScannerSettings, recipe.VoxelSize, etc. We then use these values
    % to build up the tile scan pattern.
    success=obj.recordScannerSettings;

    if ~success
        tilePosArray=[];
        tileIndexArray=[];
        if ~quiet
            fprintf('ERROR: no scanner connected. Please connect a scanner.\n')
        end
        return
    end

    if isempty(obj.FrontLeft.X) ||isempty(obj.FrontLeft.Y)
        tilePosArray=[];
        tileIndexArray=[];
        if ~quiet
            fprintf('ERROR: no front-left position defined. Can not calculate tile pattern.\n')
        end
        return
    end


    fov_x_MM = obj.ScannerSettings.FOV_alongColsinMicrons/1E3;
    fov_y_MM = obj.ScannerSettings.FOV_alongRowsinMicrons/1E3;


    % Calculate the number of tiles. The code is written with the following assumption:
    % The fast scan axis (or the columns of the image) extend along the direction of the X stage (which moves left/right WRT to the user standing in front of the system)
    % The slow scan axis (or the rows of the image) extend along the direction of the Y stage (which moves front/back WRT to the user standing in front of the system)
    % These conventions will be most important if we are are working with non-square images, as failing to adhere to the conventions will lead to images that can't be
    % stitched.
    obj.NumTiles.X = ceil(obj.mosaic.sampleSize.X / ((1-obj.mosaic.overlapProportion) * fov_x_MM) );
    obj.NumTiles.Y = ceil(obj.mosaic.sampleSize.Y / ((1-obj.mosaic.overlapProportion) * fov_y_MM) );

    if obj.verbose
        fprintf('recipe.tilePattern is making array of X=%d by Y=%d tiles. Tile FOV: %0.3f x %0.3f mm. Overlap: %0.1f%%.\n',...
            obj.NumTiles.X, obj.NumTiles.Y, fov_x_MM, fov_y_MM, round(obj.mosaic.overlapProportion*100,2));
    end

    %first column is the image obj.NumTiles.X and second is the image obj.NumTiles.Y
    tilePosArray = zeros(obj.NumTiles.Y*obj.NumTiles.X, 2);
    R=repmat(1:obj.NumTiles.Y,obj.NumTiles.X,1);
    tilePosArray(:,2)=R(:);
    theseCols=1:obj.NumTiles.X;

    for ii=1:obj.NumTiles.X:size(tilePosArray,1)
        tilePosArray(ii:ii+obj.NumTiles.X-1,1)=theseCols;
        theseCols=fliplr(theseCols);
    end

    %subtract 1 because we want offsets from zero (i.e. how much to move)
    tileIndexArray = tilePosArray; %Store the tile indexes in the grid

    tilePosArray = tilePosArray-1;

    tilePosArray = (tilePosArray*fov_x_MM)*(1-obj.mosaic.overlapProportion); %TODO: FIX

    tilePosArray = tilePosArray*-1; %because left and forward are negative and we define first position as front left
    tilePosArray(:,1) = tilePosArray(:,1)+obj.FrontLeft.X;
    tilePosArray(:,2) = tilePosArray(:,2)+obj.FrontLeft.Y;

    %Check that none of these will produce out of bounds motions
    msg='';
    if ~isempty(obj.parent) && isa(obj.parent,'tiler') && isvalid(obj.parent)

        if min(tilePosArray(:,1)) < obj.parent.xAxis.getMinPos
            msg=sprintf('%sMinimum allowed X position is %0.2f but tile position array will extend to %0.2f\n',...
                msg, min(tilePosArray(:,1)), obj.parent.xAxis.getMinPos);
        end
        if max(tilePosArray(:,1)) > obj.parent.xAxis.getMaxPos
            msg=sprintf('%sMaximum allowed X position is %0.2f but tile position array will extend to %0.2f\n',...
                msg, max(tilePosArray(:,1)), obj.parent.xAxis.getMaxPos);
        end

        if min(tilePosArray(:,2)) < obj.parent.yAxis.getMinPos
            msg=sprintf('%sMinimum allowed X position is %0.2f but tile position array will extend to %0.2f\n',...
                msg, min(tilePosArray(:,2)), obj.parent.yAxis.getMinPos);
        end
        if max(tilePosArray(:,2)) > obj.parent.yAxis.getMaxPos
            msg=sprintf('%sMaximum allowed X position is %0.2f but tile position array will extend to %0.2f\n',...
                msg, max(tilePosArray(:,2)), obj.parent.yAxis.getMinPos);
        end

    else

        msg=fprintf('No valid tiler object connected to recipe class. Can not generate tile pattern\n');

    end


    if ~isempty(msg)
        fprintf('\n** ERROR:\n%sNot returning any tile positions. Try repositioning your sample.\n',msg)
        tilePosArray=[];
        tileIndexArray=[];
    end


    %Update the tile step size (how far the stage moves between tiles) in mm to four decimal places
    obj.TileStepSize.X = round(fov_x_MM * (1-obj.mosaic.overlapProportion),4);
    obj.TileStepSize.Y = round(fov_y_MM * (1-obj.mosaic.overlapProportion),4);

end
