function pltinfo = spins_plot2d(var, t_index, varargin)
%  SPINS_PLOT2D  Plot cross-sections, averages or standard deviations of variables.
%
%  Usage:
%	pltinfo = spins_plot2d(var, t_i) plots var at t_i
%	pltinfo = spins_plot2d(var, 't') plots var at nearest output to time t (in seconds)
%	pltinfo = spins_plot2d(var, t_i, 'opt1', val1, ...) plots var at t_i with option 'opt1' as val1
%   
%  Inputs:
%    'var' may be of different forms:
%	any field in the working directory ('rho','u',...)
%   'Density'       reads rho or calculates it from Salt and Temp
%   'KE'            local kinetic energy
%   'speed'         magnitude of the local velocity
%   'Ri'            gradient Richardson number
%   'Streamline'    streamlines in the x-z plane
%   'Mean ...'      takes the spanwise mean of ...
%   'SD ...'        takes the spanwise standard deviation of ...
%   'Scaled SD ...' scales SD ... by the maximum of ...
%
%    't_index' may be:
%   an integer for a particular output
%   a vector of outputs (ie. 0:10) will plot each output successively in the same figure
%   a string containing the time (ex. '15')
%
%    Optional arguments:
%	Name:	Options			- Description (defaults are in spins_plotoptions.m)
%	---------------------------------------------------------
%   dimen:  {'X','Y','Z'}       - dimension to take cross-section
%   slice:  {double}            - location to take cross-section
%   axis:   {[x1 x2 z1 z2]}     - domain to plot
%   style:  {'pcolor','contourf','contour'}     - type of plot
%   xskp:   {integer}           - x-grid points to skip in plot
%   yskp:   {integer}           - y-grid     "
%   zskp:   {integer}           - z-grid     "
%   fnum:   {integer}           - figure window to make plot
%   cont2:  {field name}        - secondary field to plot as contours
%   ncont2:    {integer}        - contours to use for secondary field
%   ncontourf: {integer}        - contours to use for contourf plot
%   ncontour:  {integer}        - contours to use for contour plot
%   ncmap:     {double}         - number of levels in pcolor colormap
%   colaxis:   {[c1 c2]}        - color axis limits to use
%   colorbar:  {boolean}        - plot colorbar?
%   trim:      {boolean}        - trims values outside colaxis range
%   visible:   {boolean}        - make figure visible?
%   speed:     {double}         - wave speed to subtract from flow in streamline plot
%   savefig:   {boolean}        - save figure in figure file?
%   filename:  {string}         - name of file of saved figure
%   dir:       {string}         - name of relative directory to save figure
%
%  Outputs:
%    'pltinfo'	- a structure containing the plotted fields 
%
%  David Deepwell, 2015
global gdpar

% get grid and parameters
gd = gdpar.gd;
params = gdpar.params;
if ~strcmp(params.mapped_grid,'true') && ~isvector(gd.x)
    gd = get_vector_grid(gd);
end

% set plotting options
spins_plotoptions

% open new figure
if strcmpi(opts.fnum, 'New')
    fighand = figure;
else
    fighand = figure(opts.fnum);
end
% figure visibility options
if opts.visible == false
    set(fighand, 'Visible', 'off')
end

for ii = t_index
    clf
    hold on
    % Title
    plot_title = var;
    if strncmp(var,'Mean',4) || strncmp(var,'SD',2)
        plot_title = ['Spanwise ', plot_title];
    end
    if params.ndims == 3	% add cross-section information
        plot_title = [plot_title,', ',opts.dimen,'=',num2str(opts.slice),' m'];
    end
    if isfield(params, 'plot_interval')	% add time in seconds or output number
        plot_title = [plot_title,', t=',num2str(ii*params.plot_interval),' s'];
    else
        plot_title = [plot_title,', t_n=',int2str(ii)];
    end
    title(plot_title);
    % axis labels
    if strcmp(opts.dimen, 'X')
        xlabel('y (m)'), ylabel('z (m)')
    elseif strcmp(opts.dimen, 'Y')
        xlabel('x (m)'), ylabel('z (m)')
    elseif strcmp(opts.dimen, 'Z')
        xlabel('x (m)'), ylabel('y (m)')
    end

    % get data to plot
    data1 = spins_readdata(var,ii,nx,ny,nz,opts.dimen);
    % if mapped grid and taking horizontal opts.slice, then find interpolation
    if strcmp(opts.dimen, 'Z') && strcmp(params.mapped_grid, 'true')
        [xvar, yvar, data1] = get_fixed_z(xvar, yvar, zvar, data1, opts.slice);
    end
    % transpose unmapped data
    if strcmp(params.mapped_grid, 'false') && ~strcmp(var, 'Streamline')
        data1 = data1';
    end
    % remove points outside of desirable plotting range (typically from spectral aliasing)
    % this sets more contour levels into region that matters
    if opts.trim == true
        if opts.colaxis == 0
            error('Trim requires an axis range to trim into.')
        else
            data1(data1>opts.colaxis(2)) = opts.colaxis(2);
            data1(data1<opts.colaxis(1)) = opts.colaxis(1);
        end
    end

    % choose plotting style (contourf may take up less memory,
    % but can be slower than pcolor)
    if strcmpi(var,'Streamline')
        if strcmp(params.mapped_grid, 'true')
            warning('Streamline has not been tested for mapped grids.')
        end
        if opts.speed == -1
            prompt = 'Provide a sensible wave speed in m/s: ';
            uwave = input(prompt);
        else
            uwave = opts.speed;
        end
        disp(['background speed = ',num2str(uwave),' m/s'])
        u1 = data1(:,:,1) - uwave;
        u2 = data1(:,:,2);
        data1(:,:,1) = u1;
        p_hand = streamslice(xvar,yvar,u1',u2',2,'noarrows','cubic');
        cont2col = 'r-';
    elseif strcmp(opts.style,'pcolor')
        p_hand = pcolor(xvar,yvar,data1);
        cont2col = 'k-';
    elseif strcmp(opts.style,'contourf')
        [~,p_hand] = contourf(xvar,yvar,data1,opts.ncontourf);
        cont2col = 'k-';
    elseif strcmp(opts.style,'contour')
        [~,p_hand] = contour(xvar,yvar,data1,opts.ncontour);
        cont2col = 'k-';
    end

    % get caxis limits
    [colaxis, cmap] = choose_caxis(var, data1, opts);
    % use user defined caxis if specified
    if length(opts.colaxis) ~= 1
        colaxis = opts.colaxis;
    end

    % add extra information
    shading flat
    if strcmp(opts.style,'contourf')
        set(p_hand,'LineColor','none')
    end
    colormap(cmap)
    if ~strcmp(colaxis, 'auto')
        caxis(colaxis);
    end
    if opts.colorbar == true && ~strcmp(var, 'Streamline')
        colorbar
    end

    % add contours of another field
    if ~strcmpi(opts.cont2,'None')
        if (strncmp(var,'Mean',4) || strncmp(var,'SD',2)) && ~strcmp(opts.cont2,'Streamline')
            % choose Mean of field if primary field is Mean or SD
            cont2 = ['Mean ',opts.cont2];
        else
            cont2 = opts.cont2;
        end
        if strcmp(cont2,var)            % read in data only if the field is different
            data2 = data1;
        else
            data2 = spins_readdata(cont2,ii,nx,ny,nz,opts.dimen);
            if strcmp(opts.dimen, 'Z') && strcmp(params.mapped_grid, 'true')
                [xvar, yvar, data2] = get_fixed_z(xvar, yvar, zvar, data2, opts.slice);
            end
            if strcmp(params.mapped_grid, 'false') && ~strcmp(opts.cont2, 'Streamline')
                data2 = data2';
            end
            if strcmp(opts.cont2, 'Streamline')
                if strcmp(params.mapped_grid, 'true')
                    warning('Streamline has not been tested for mapped grids.')
                end
                if opts.speed == -1
                    prompt = 'Provide a sensible wave speed in m/s: ';
                    uwave = input(prompt);
                else
                    uwave = opts.speed;
                end
                disp(['background speed = ',num2str(uwave),' m/s'])
                u1 = data2(:,:,1) - uwave;
                u2 = data2(:,:,2);
                data2(:,:,1) = u1;
                streamslice(xvar,yvar,u1',u2',2,'noarrows','cubic')
            else
                contour(xvar,yvar,data2,opts.ncont2,cont2col)
            end
        end
    end
    if strcmp(var, 'Ri')
        contour(xvar, yvar, data1, [1 1]*0.25, 'r-');
    end

    % add contour of hill if grid is mapped
    if strcmp(params.mapped_grid,'true')
        hill_nx = nx(1):nx(end);
        if params.ndims == 3
            hill   = squeeze(gd.z(hill_nx,1,params.Nz));
            hill_x = squeeze(gd.x(hill_nx,1,params.Nz));
        elseif params.ndims == 2
            hill   = squeeze(gd.z(hill_nx,params.Nz));
            hill_x = squeeze(gd.x(hill_nx,params.Nz));
        end
        plot(hill_x,hill,'k')
    end

    % axis options
    if (plotaxis(2)-plotaxis(1))/(plotaxis(4)-plotaxis(3)) > 5
        axis normal
    else
        axis image
    end
    axis(plotaxis)
    set(gca,'layer','top')
    box on

    % drawnow if plotting multiple outputs
    if length(t_index) > 1, drawnow, end

    % save figure
    if opts.savefig == true
        direcs = strsplit(opts.dir, '/');
        strt_dir  = pwd;
        for jj = 1:length(direcs)
            if ~(exist(direcs{jj},'dir') == 7)
                mkdir(direcs{jj})
            end
            cd(direcs{jj})
        end
        savefig(gcf,[filename,'_',int2str(ii)]);
        cd(strt_dir)
    end
    hold off

    % output plotted data
    if strcmp(params.mapped_grid, 'false') && ~strcmp(var, 'Streamline')
        data1 = data1';
        try
            data2 = data2';
        end
    end
    pltinfo.xvar = xvar;
    pltinfo.yvar = yvar;
    pltinfo.data1 = data1;
    pltinfo.var1 = var;
    try
        pltinfo.data2 = data2;
        pltinfo.var2 = cont2;
    end
    pltinfo.dimen = opts.dimen;
    pltinfo.slice = opts.slice;

end