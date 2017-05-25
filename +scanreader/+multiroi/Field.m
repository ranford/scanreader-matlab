classdef Field < handle
    % FIELD Small container for field information.
    %
    % When a field is formed by joining two or more subfields (via join_contiguous), the 
    % slice lists hold two or more slices representing where each subfield will be taken
    % from the page and inserted in the (joint) output field. Attributes height, width, x,
    % y, heightInDegrees and widthInDegrees are adjusted accordingly. For non-contiguous  
    % fields, each slice list has a single slice.
    % 
    %  Note:
    %     Slices in xSlices, ySlices, outputXSlices and outputYSlices hold two promises:
    %         step = 1 (fields are contiguous)
    %         stop = start + height|width 
    %     In theory, we only need x_start and y_start but slices simplify operations.
        
    properties
        height % height of the field in pixels
        width % width of the field in pixels
        depth % depth at which this field was recorded (in microns relative to absolute z)
        y % y coordinate of the center of the field in the scan (in scan angle degrees)
        x % x coordinate of the center of the field in the scan (in scan angle degrees)
        heightInDegrees % height of the field in degrees of the scan angle
        widthInDegrees % width of the field in degrees of the scan angle
        ySlices % array of slices. How to slice the page in the y axis to get this field
        % array of slices. How to slice the page in the x axis to get this field. For now,
        % all fields have the same width so all xslices are slice(None).
        xSlices
        outputYSlices % array of slices. Where to paste this field in the output field
        outputXSlices % array of slices. Where to paste this field in the output field
    end
    properties(Dependent)
        hasContiguousSubfields % true if this field is made by joining two or more subfields
    end
    
    methods
        function obj = Field(height, width, depth, y, x, heightInDegrees, widthInDegrees,...
                ySlices, xSlices, outputYSlices, outputXSlices)
            if nargin >= 1 obj.height = height; end
            if nargin >= 2 obj.width = width; end
            if nargin >= 3 obj.depth = depth; end
            if nargin >= 4 obj.y = y; end
            if nargin >= 5 obj.x = x; end
            if nargin >= 6 obj.heightInDegrees = heightInDegrees; end
            if nargin >= 7 obj.widthInDegrees = widthInDegrees; end
            if nargin >= 8 obj.ySlices = ySlices; end
            if nargin >= 9 obj.xSlices = xSlices; end
            if nargin >= 10 obj.outputYSlices = outputYSlices; end
            if nargin >= 11 obj.outputXSlices = outputXSlices; end
        end
        
        function hasContiguousSubfields = get.hasContiguousSubfields(obj)
            % HASCONTIGUOUSSUBFIELDS Whether field is formed by many contiguous subfields.
            hasContiguousSubfields = length(obj.xSlices) > 1;
        end
        
        function field = copy(obj)
            field = scanreader.multiroi.Field(obj.height, obj.width, obj.depth, ...
                obj.y, obj.x, obj.heightInDegrees, obj.widthInDegrees, obj.ySlices, ...
                obj.xSlices, obj.outputYSlices, obj.outputXSlices);
        end
        
        function areContiguous = iscontiguousto(obj, field2)
            % ISCONTIGUOUSTO Whether this field is contiguous to field2.
            areContiguous = ~(obj.typeofcontiguity(field2) == scanreader.multiroi.Position.Noncontiguous);
        end
        
        function joinwith(obj, field2)
            % JOINWITH Update attributes of this field to incorporate field2. Field2 is
            % NOT changed.
            contiguity = obj.typeofcontiguity(field2);
            if contiguity == scanreader.multiroi.Position.Above || contiguity == ...
                    scanreader.multiroi.Position.Below
                % Compute some specific attributes
                if contiguity == scanreader.multiroi.Position.Above % field2 is above/atop self
                    newY = field2.y + (obj.heightInDegrees / 2);
                    outputYSlices1 = cellfun(@(slice) slice + field2.height, obj.outputYSlices, 'uniformOutput', false);
                    outputYSlices2 = field2.outputYSlices;
                else % field2 is below self
                    newY = obj.y + (field2.heightInDegrees /2);
                    outputYSlices1 = obj.outputYSlices;
                    outputYSlices2 = cellfun(@(slice) slice + obj.height, field2.outputYSlices, 'uniformOutput', false);
                end
                
                % Set new attributes
                obj.y = newY;
                obj.height = obj.height + field2.height;
                obj.heightInDegrees = obj.heightInDegrees + field2.heightInDegrees;
                obj.outputYSlices = [outputYSlices1, outputYSlices2];
                obj.outputXSlices = [obj.outputXSlices, field2.outputXSlices];
            end

            if contiguity == scanreader.multiroi.Position.Left || contiguity == ...
                    scanreader.multiroi.Position.Right
                % Compute some specific attributes
                if contiguity == scanreader.multiroi.Position.Left % field2 is to the left of self
                    newX = field2.x + (obj.widthInDegrees /2);
                    outputXSlices1 = cellfun(@(slice) slice + field2.width, obj.outputXSlices, 'uniformOutput', false);
                    outputXSlices2 = obj.outputXSlices;
                else % field2 is to the right of self
                    newX = obj.x + (field2.widthInDegrees / 2);
                    outputXSlices1 = obj.outputXSlices;
                    outputXSlices2 = cellfun(@(slice) slice + obj.width, field2.outputXSlices, 'uniformOutput', false);
                end
                
                % Set new attributes
                obj.x = newX;
                obj.width = obj.width + field2.width;
                obj.widthInDegrees = obj.widthInDegrees + field2.widthInDegrees;
                obj.outputYSlices = [obj.outputYSlices, field2.outputYSlices];
                obj.outputXSlices = [outputXSlices1, outputXSlices2];
            end

            % yslices and xslices just get appended regardless of the type of contiguity
            obj.ySlices = [obj.ySlices, field2.ySlices];
            obj.xSlices = [obj.xSlices, field2.xSlices];
        end
    end
    
    methods(Access = private)
        function position = typeofcontiguity(obj, field2)
            % TYPEOFCONTIGUITY Compute how field 2 is contiguous to this one.
            % 
            % position = TYPEOFCONTIGUITY(FIELD2) returns an enum value from
            % multiroi.Position (NonContiguous, Above, Below, Left or Right) depending on
            % whether FIELD2 is above, below, to the left or to the right of this field.
            position = scanreader.multiroi.Position.Noncontiguous;
            epsilon = eps('single'); % max acceptable difference between floats
            if abs(obj.widthInDegrees - field2.widthInDegrees) < epsilon
                expectedDistance = obj.heightInDegrees / 2 + field2.heightInDegrees / 2;
                if abs(obj.y - (field2.y + expectedDistance)) < epsilon
                    position = scanreader.multiroi.Position.Above;
                end
                if abs(field2.y - (obj.y + expectedDistance)) < epsilon
                    position = scanreader.multiroi.Position.Below;
                end
            end
            if abs(obj.heightInDegrees - field2.heightInDegrees) < epsilon
                expectedDistance = obj.widthInDegrees / 2 + field2.widthInDegrees / 2;
                if abs(obj.x - (field2.x + expectedDistance)) < epsilon
                    position = scanreader.multiroi.Position.Left;
                end
                if abs(field2.x - (obj.x + expectedDistance)) < epsilon
                    position = scanreader.multiroi.Position.Right;
                end 
            end
        end
    end
    
end