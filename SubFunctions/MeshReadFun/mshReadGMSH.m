function [v, f] = mshReadGMSH(fileName)
%MESHREADGMSH reads a .msh file written in ASCII format by GMSH
%V are the vertices
%F are the faces

% /!\ ONLY EXTRACT 2D ELEMENTS /!\
% The present code ONLY works for meshes composed of triangular
% facets.
% -------------------------------------------------------------------------
% read the mesh file

fstring = fileread(fileName); % read the file as one string

%% Get the format of the mesh file
fblocks_in = regexp(fstring,'\$[a-zA-Z]+','split');
fblocks_border = regexp(fstring,'\$[a-zA-Z]+','match');

for i = 1:length(fblocks_border)
    if strcmp(fblocks_border{i} , '$MeshFormat')
        msh_format = textscan(fblocks_in{i+1},'%f %d %d','delimiter',' ','MultipleDelimsAsOne', 1);
        msh_vers = msh_format{1}; msh_binary = msh_format{2};
        disp(fileName)
        disp(msh_vers)
        break
    end
end

if msh_binary
    warnings('The function can not read binary data yet')
end

if msh_vers >= 2.0 && msh_vers < 3
    %% Format 2
    % Separate the file at '$' separator
    fblocks = regexp(fstring,'\$[a-zA-Z]+','split'); % $.... as separator
    
    v_raw = textscan(fblocks{4},'%f %f %f %f','delimiter',' ','MultipleDelimsAsOne', 1);
    v_raw = horzcat(v_raw{:});
    
    f_raw = textscan(fblocks{6},'%f %f %f %f %f %f %f %f','delimiter',' ','MultipleDelimsAsOne', 1);
    f_raw = horzcat(f_raw{:});
    
    % Extract part of the data that we are interested in
    v = v_raw(2:end,2:end);
    f = f_raw(2:end,6:end);
    
elseif msh_vers >= 3.0 && msh_vers < 4
    %% Format 3
    warning('Parser for mesh format 3.x is not implemented yet')
    % To DO
    
elseif msh_vers >= 4.0 && msh_vers < 5
    %% Format 4
    for i = i : length(fblocks_border)
        if strcmp(fblocks_border{i} , '$Nodes')
            % Get numbers of nodes
            expreNumberofNodes = '^\d+\s(\d+)\s\d+\s\d+[\r\n]+';
            [tokens, ~] = regexp(fblocks_in{i+1}, expreNumberofNodes,'tokens', 'match','lineanchors');
            nodesWithID = zeros(str2num(tokens{1}{1}),4);
            
            % Find nodes Id number
            expreNodesID = '(?:^(\d+)\s*[\r\n])+';
            [~,matches] = regexp(fblocks_in{i+1}, expreNodesID,'tokens', 'match','lineanchors');
            kstart = 1 ;
            for j = 1:length(matches)
                new_nodes = str2num(matches{j});
                kend = kstart + length(new_nodes) - 1;
                nodesWithID(kstart:kend,1) = new_nodes;
                kstart = kend + 1;
            end
            
            % Find Nodes Coordinates
            expreNodesCoor = '^(-?\d+\.?\d*)\s(-?\d+\.?\d*)\s(-?\d+\.?\d*)\s$';
            [tokens,matches] = regexp(fblocks_in{i+1}, expreNodesCoor,'tokens', 'match','lineanchors');
            nodesCoor = cellfun(@str2num, vertcat(tokens{:})) ;
            
            nodesWithID(:,2:4) = nodesCoor;
            
        elseif strcmp(fblocks_border{i} , '$Elements')
            elmtsWithID = [];
            expre2DElem = '^2\s\d+\s2\s(\d+)\s?$';
            elem2D_in = regexp(fblocks_in{i+1},expre2DElem,'split','lineanchors');
            [elem2DEntSize,~] = regexp(fblocks_in{i+1}, expre2DElem,'tokens', 'match','lineanchors');
            for j = 2 : length(elem2D_in)
                elem = textscan(elem2D_in{j},'%d %d %d %d','delimiter',' ','MultipleDelimsAsOne', 1);
                elem = [elem{1} elem{2} elem{3} elem{4}];
                elem = elem(1:str2num(elem2DEntSize{j-1}{1}),:);
                elmtsWithID = [elmtsWithID ; elem];
            end
        end
    end
    
    % Simplify the Nodes numbering
    if max(nodesWithID(:,1)) > length(nodesWithID(:,1))
        % Look Up table
        LUT(nodesWithID(:,1)) = 1: length(nodesWithID(:,1));
        % Change references Nodes ID in the elements connectivity list
        elmtsWithID(:,2:4) = LUT(elmtsWithID(:,2:4));
    end
    
    % results
    v = nodesWithID(:,2:end);
    f = double(elmtsWithID(:,2:end));
    
elseif msh_vers >= 5.0
    warning('Parser for mesh format 5.0 and above is not implemented yet')
    
    
end

if length(f) < 100
    warnings('/!\ Very few elements (<100) have been read from the .msh file')
end

end

%======================
% GMSH .msh ascii file format 2.X
%======================
% ASCII STL files have the following structure.  Technically each facet
% could be any 2D shape, but in practice only triangular facets tend to be
% used.  The present code ONLY works for meshes composed of triangular
% facets.
%
% $MeshFormat
%   mesh format code
% $EndMeshFormat
% $Nodes
%   Number of nodes
%   Node_index x y z
%       ---
%   Node_index x y z
% $EndNodes
% $Elements
%  Number of elements
% 	Element_ID element_type(4 int) Node1_index Node2_index Node3_index
%                           ---
%   Element_ID element_type(4 int) Node1_index Node2_index Node3_index
% $EndElements
%==========================================================================


%==========================================================================
%======================
% GMSH .msh ascii file format 4.X
%======================
% $MeshFormat // same as MSH version 2
%   version(ASCII double; currently 4.1)
%     file-type(ASCII int; 0 for ASCII mode, 1 for binary mode)
%     data-size(ASCII int; sizeof(size_t))
%   < int with value one; only in binary mode, to detect endianness >
% $EndMeshFormat
%
% $PhysicalNames // same as MSH version 2
%   numPhysicalNames(ASCII int)
%   dimension(ASCII int) physicalTag(ASCII int) "name"(127 characters max)
%   ...
% $EndPhysicalNames
%
% $Entities
%   numPoints(size_t) numCurves(size_t)
%     numSurfaces(size_t) numVolumes(size_t)
%   pointTag(int) X(double) Y(double) Z(double)
%     numPhysicalTags(size_t) physicalTag(int) ...
%   ...
%   curveTag(int) minX(double) minY(double) minZ(double)
%     maxX(double) maxY(double) maxZ(double)
%     numPhysicalTags(size_t) physicalTag(int) ...
%     numBoundingPoints(size_t) pointTag(int) ...
%   ...
%   surfaceTag(int) minX(double) minY(double) minZ(double)
%     maxX(double) maxY(double) maxZ(double)
%     numPhysicalTags(size_t) physicalTag(int) ...
%     numBoundingCurves(size_t) curveTag(int) ...
%   ...
%   volumeTag(int) minX(double) minY(double) minZ(double)
%     maxX(double) maxY(double) maxZ(double)
%     numPhysicalTags(size_t) physicalTag(int) ...
%     numBoundngSurfaces(size_t) surfaceTag(int) ...
%   ...
% $EndEntities
%
% $PartitionedEntities
%   numPartitions(size_t)
%   numGhostEntities(size_t)
%     ghostEntityTag(int) partition(int)
%     ...
%   numPoints(size_t) numCurves(size_t)
%     numSurfaces(size_t) numVolumes(size_t)
%   pointTag(int) parentDim(int) parentTag(int)
%     numPartitions(size_t) partitionTag(int) ...
%     X(double) Y(double) Z(double)
%     numPhysicalTags(size_t) physicalTag(int) ...
%   ...
%   curveTag(int) parentDim(int) parentTag(int)
%     numPartitions(size_t) partitionTag(int) ...
%     minX(double) minY(double) minZ(double)
%     maxX(double) maxY(double) maxZ(double)
%     numPhysicalTags(size_t) physicalTag(int) ...
%     numBoundingPoints(size_t) pointTag(int) ...
%   ...
%   surfaceTag(int) parentDim(int) parentTag(int)
%     numPartitions(size_t) partitionTag(int) ...
%     minX(double) minY(double) minZ(double)
%     maxX(double) maxY(double) maxZ(double)
%     numPhysicalTags(size_t) physicalTag(int) ...
%     numBoundingCurves(size_t) curveTag(int) ...
%   ...
%   volumeTag(int) parentDim(int) parentTag(int)
%     numPartitions(size_t) partitionTag(int) ...
%     minX(double) minY(double) minZ(double)
%     maxX(double) maxY(double) maxZ(double)
%     numPhysicalTags(size_t) physicalTag(int) ...
%     numBoundingSurfaces(size_t) surfaceTag(int) ...
%   ...
% $EndPartitionedEntities
%
% $Nodes
%   numEntityBlocks(size_t) numNodes(size_t)
%     minNodeTag(size_t) maxNodeTag(size_t)
%   entityDim(int) entityTag(int) parametric(int; 0 or 1)
%     numNodesInBlock(size_t)
%     nodeTag(size_t)
%     ...
%     x(double) y(double) z(double)
%        < u(double; if parametric and entityDim >= 1) >
%        < v(double; if parametric and entityDim >= 2) >
%        < w(double; if parametric and entityDim == 3) >
%     ...
%   ...
% $EndNodes
%
% $Elements
%   numEntityBlocks(size_t) numElements(size_t)
%     minElementTag(size_t) maxElementTag(size_t)
%   entityDim(int) entityTag(int) elementType(int; see below)
%     numElementsInBlock(size_t)
%     elementTag(size_t) nodeTag(size_t) ...
%     ...
%   ...
% $EndElements
%
% $Periodic
%   numPeriodicLinks(size_t)
%   entityDim(int) entityTag(int) entityTagMaster(int)
%   numAffine(size_t) value(double) ...
%   numCorrespondingNodes(size_t)
%     nodeTag(size_t) nodeTagMaster(size_t)
%     ...
%   ...
% $EndPeriodic
%
% $GhostElements
%   numGhostElements(size_t)
%   elementTag(size_t) partitionTag(int)
%     numGhostPartitions(size_t) ghostPartitionTag(int) ...
%   ...
% $EndGhostElements
%
% $Parametrizations
%   numCurveParam(size_t) numSurfaceParam(size_t)
%   curveTag(int) numNodes(size_t)
%     nodeX(double) nodeY(double) nodeZ(double) nodeU(double)
%     ...
%   ...
%   surfaceTag(int) numNodes(size_t) numTriangles(size_t)
%     nodeX(double) nodeY(double) nodeZ(double)
%       nodeU(double) nodeV(double)
%       curvMaxX(double) curvMaxY(double) curvMaxZ(double)
%       curvMinX(double) curvMinY(double) curvMinZ(double)
%     ...
%     nodeIndex1(int) nodeIndex2(int) nodeIndex3(int)
%     ...
%   ...
% $EndParametrizations
%
% $NodeData
%   numStringTags(ASCII int)
%   stringTag(string) ...
%   numRealTags(ASCII int)
%   realTag(ASCII double) ...
%   numIntegerTags(ASCII int)
%   integerTag(ASCII int) ...
%   nodeTag(size_t) value(double) ...
%   ...
% $EndNodeData
%
% $ElementData
%   numStringTags(ASCII int)
%   stringTag(string) ...
%   numRealTags(ASCII int)
%   realTag(ASCII double) ...
%   numIntegerTags(ASCII int)
%   integerTag(ASCII int) ...
%   elementTag(size_t) value(double) ...
%   ...
% $EndElementData
%
% $ElementNodeData
%   numStringTags(ASCII int)
%   stringTag(string) ...
%   numRealTags(ASCII int)
%   realTag(ASCII double) ...
%   numIntegerTags(ASCII int)
%   integerTag(ASCII int) ...
%   elementTag(size_t) numNodesPerElement(int) value(double) ...
%   ...
% $EndElementNodeData
%
% $InterpolationScheme
%   name(string)
%   numElementTopologies(ASCII int)
%   elementTopology
%   numInterpolationMatrices(ASCII int)
%   numRows(ASCII int) numColumns(ASCII int) value(ASCII double) ...
% $EndInterpolationScheme
%==========================================================================