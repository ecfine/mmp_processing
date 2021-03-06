function setstext(anchor,p1,v1,p2,v2,p3,v3,p4,v4,p5,v5,...
		p6,v6,p7,v7,p8,v8,p9,v9,p10,v10,p11,v11,p12,v12)
%SETSTEXT Set styled text object properties.
% SETSTEXT has the same syntax as SET except that only one styled text
% handle can be specified and SETSTEXT(H) does not display all the
% property names and possible values.
%
% See also SET, STEXT, SXLABEL, SYLABEL, SZLABEL, STITLE, DELSTEXT
% PRINTSTO, FIXSTEXT.

% Requires functions CMDMATCH and GETCARGS and MAT-file STFMMAC.MAT
% or STFMLAT1.MAT (depending on platform).
% Requires MATLAB Version 4.2 or greater.

% Version 2.1, 8 September 1995
% Part of the Styled Text Toolbox
% Copyright 1995 by Douglas M. Schwarz.  All rights reserved.
% schwarz@kodak.com

% Define gFONT_METRICS, gKERNING_DATA and gACCENT_CODES as global
% variables so we only have to load them if they weren't loaded
% by stext or have been cleared.
global gFONT_METRICS gKERNING_DATA gACCENT_CODES
if length(gFONT_METRICS) == 0
	stextfun = which('stext');
	stextfun((length(stextfun) - 6):length(stextfun)) = [];
	comp = computer;
	if strcmp(comp(1:2),'MA')
		load([stextfun,'stfmmac.mat'])
	else
		load([stextfun,'stfmlat1.mat'])
	end
end

% Check to see if handle is a valid stext object.
tag = get(anchor,'Tag');
if ~strcmp(tag(1:min(length(tag),5)),'stext')
	error('Not an stext object.')
end

% Get default values.
str           = get(anchor,'String');
anchorPos     = get(anchor,'Position');
horizAlign    = get(anchor,'HorizontalAlignment');
vertAlign     = get(anchor,'VerticalAlignment');
anchorUnits   = get(anchor,'Units');
rotation      = get(anchor,'Rotation');
eraseMode     = get(anchor,'EraseMode');
buttonDownFcn = get(anchor,'ButtonDownFcn');
clipping      = get(anchor,'Clipping');
interruptible = get(anchor,'Interruptible');
fontSize      = get(0,'DefaultTextFontSize');
fontName      = lower(get(0,'DefaultTextFontName'));
color         = get(0,'DefaultTextColor');

set(anchor,'Rotation',0,'Visible','off','Color','i')
userData = get(anchor,'UserData');
oldObjList = userData(4:length(userData));
if length(oldObjList) > 0
	visible = get(oldObjList(1),'Visible');
else
	visible = 'on';
end

% Look for and set some properties
numOptions = (nargin - 1)/2;
for i = 1:numOptions
	property = eval(['p',num2str(i)]);
	value = eval(['v',num2str(i)]);
	
	% Convert property and value (if it's a string) to lower case.
	% This code is significantly simpler and faster than lower.m, but
	% sufficient for our purposes.
	upperCase = property >= 'A' & property <= 'Z';
	property(upperCase) = setstr(property(upperCase) + ('a' - 'A'));
	if isstr(value) & ~cmdmatch('string',property)
		upperCase = value >= 'A' & value <= 'Z';
		value(upperCase) = setstr(value(upperCase) + ('a' - 'A'));
	end
	
	% HorizontalAlignment: [ {left} | center | right ]
	if cmdmatch('horizontalalignment',property)
		horizAlign = value;
		set(anchor,'HorizontalAlignment',value)
	
	% VerticalAlignment: [ top | cap | {middle} | baseline | bottom ]
	elseif cmdmatch('verticalalignment',property)
		vertAlign = value;
		set(anchor,'VerticalAlignment',value)
	
	% Units: [ inches | centimeters | normalized | points | pixels | {data} ]
	elseif cmdmatch('units',property)
		anchorUnits = value;
		set(anchor,'Units',value)
		anchorPos = get(anchor,'Position');
	
	% Position
	elseif cmdmatch('position',property)
		anchorPos = value;
		set(anchor,'Position',value)
		xin = value(1);
		yin = value(2);
	
	% Rotation
	elseif cmdmatch('rotation',property)
		rotation = 90*round(value/90);
		rotation = rotation - floor(rotation/360)*360;
	
	% String
	elseif cmdmatch('string',property)
		str = value;
		set(anchor,'String',value)
	
	% EraseMode
	elseif cmdmatch('erasemode',property)
		eraseMode = value;
		set(anchor,'EraseMode',value)
	
	% ButtonDownFcn
	elseif cmdmatch('buttondownfcn',property)
		buttonDownFcn = value;
		set(anchor,'ButtonDownFcn',value)
	
	% Clipping
	elseif cmdmatch('clipping',property)
		clipping = value;
		set(anchor,'Clipping',value)
	
	% Interruptible
	elseif cmdmatch('interruptible',property)
		interruptible = value;
		set(anchor,'Interruptible',value)
	
	% Visible
	elseif cmdmatch('visible',property)
		visible = value;
		set(anchor,'Visible',value)
	
	else
		error('Invalid object property.')
	end
end

% Initialize some data.
set(anchor,'Units','points')
pos = get(anchor,'Position');
set(anchor,'Units',anchorUnits)
x0 = pos(1);
y0 = pos(2);
objList = [];
heightList = [];
xDistance = [];
first = 1;
terminators = setstr(32:255);
terminators(['0':'9','+-<=>|','A':'Z','a':'z'] - 31) = [];
colLut = [1 1 3 3;2 2 4 4;2 2 4 4];
fm = [1:4 ; 5:8 ; 9:12 ; 13 13 13 13 ; 14:17 ; 18:21 ; 22:25 ; 26:29 ;...
		30 30 30 30 ; 31 31 31 31 ; 32:35];

fontanglelist = str2mat('normal','italic','oblique');
fontnamelist = str2mat('times','helvetica','courier','symbol',...
		'avantgarde','bookman','newcenturyschlbk','palatino',...
		'zapfdingbats','zapfchancery','n helvetica narrow');
fontweightlist = str2mat('light','normal','demi','bold');

% Initialize indexing parameters for "params" array.  fa = font angle,
% fn = font name, fs = font size, fw = font weight, cr,cg,cb = color rgb,
% x = x location, y = y location, mode is used for super- and subscripts,
% nextX = x location of next object.
fa = 1; fn = 2; fs = 3; fw = 4; cr = 5; cg = 6; cb = 7; x = 8; y = 9;
mode = 10; nextX = 11;

% params is a parameter stack.  The contents are indices into string
% matrices for font angle, name and weight and actual values for
% the others.

% Initialize params: font angle = normal, font name = default font,
% font size = default text font size, font weight = normal,
% color = default text color, x = 0, y = 0, mode = 0, nextX = 0.
params = [1;2;fontSize;2;get(0,'DefaultTextColor')';0;0;0;0];
fontIndex = max(find(fontName(1) == fontnamelist(:,1)));
if ~isempty(fontIndex), params(fn) = fontIndex; end

% Replace '\{', '\}', '\\', '\^' and '\_' with special codes.
str = strrep(str,'\{','{'+256);
str = strrep(str,'\\','\'+256);
str = strrep(str,'\^','^'+256);
str = strrep(str,'\_','_'+256);
str = strrep(str,'\}','}'+256);

% Parse str looking for commands.
while ~isempty(str)
	if str(1) == '{'
		% Push a copy of the current parameters on the parameter stack.
		params = [params(:,1),params];
		params(mode) = 0;
		str(1) = [];
	elseif str(1) == '}'
		% Pop the parameter stack except for adjustments to the x values.
		if size(params,2) == 1
			delete(objList)
			delete(anchor)
			error('Unmatched braces.')
		end
		str(1) = [];
		params(nextX,2) = max(params(nextX),params(nextX,2));
		if params(mode,2) == 0
			params(x,2) = params(x);
		end
		if isempty(str)
			params(x,2) = params(x);
		else
			if str(1) ~= '^' & str(1) ~= '_'
				params(x,2) = params(x);
				params(mode,2) = 0;
			end
		end
		params(:,1) = [];
	elseif str(1) == '^'
		% Superscript
		params(mode) = params(mode) + 1;
		params = [params(:,1),params];
		params(mode) = 0;
		params(nextX) = params(x);
		params(y) = params(y) + params(fs)/3;
		params(fs) = params(fs)/sqrt(2);
		if str(2) == '{'
			str(1:2) = [];
		else
			str(1:2) = [str(2),'}'];
		end
	elseif str(1) == '_'
		% Subscript
		params(mode) = params(mode) + 2;
		params = [params(:,1),params];
		params(mode) = 0;
		params(nextX) = params(x);
		params(y) = params(y) - params(fs)/4;
		params(fs) = params(fs)/sqrt(2);
		if str(2) == '{'
			str(1:2) = [];
		else
			str(1:2) = [str(2),'}'];
		end
	elseif str(1) == '\'
		% Extract command.
		[cmd,str] = strtok(str,terminators);
		sp = '';
		if ~isempty(str), if str(1) == ' ', str(1) = []; sp = ' '; end, end
		
		% Font size specified in points.
		if all(cmd >= '0' & cmd <= '9')
			params(fs) = str2num(cmd);
				
		% Font angle and weight commands.
		elseif cmdmatch('normal',cmd)   params(fa) = 1; params(fw) = 2;
		elseif cmdmatch('italic',cmd),  params(fa) = 2;
		elseif cmdmatch('oblique',cmd), params(fa) = 3;
		elseif cmdmatch('light',cmd),   params(fw) = 1;
		elseif cmdmatch('demi',cmd),    params(fw) = 3;
		elseif cmdmatch('bold',cmd),    params(fw) = 4;
		
		% Font names.
		elseif cmdmatch('times',cmd),            params(fn) = 1;
		elseif cmdmatch('helvetica',cmd),        params(fn) = 2;
		elseif cmdmatch('courier',cmd),          params(fn) = 3;
		elseif cmdmatch('symbol',cmd),           params(fn) = 4;
		elseif cmdmatch('avantgarde',cmd),       params(fn) = 5;
		elseif cmdmatch('bookman',cmd),          params(fn) = 6;
		elseif cmdmatch('newcenturyschlbk',cmd), params(fn) = 7;
		elseif cmdmatch('palatino',cmd),         params(fn) = 8;
		elseif cmdmatch('zapfdingbats',cmd),     params(fn) = 9;
		elseif cmdmatch('zapfchancery',cmd),     params(fn) = 10;
		elseif cmdmatch('narrow',cmd),           params(fn) = 11;
		elseif cmdmatch('helvnarrow',cmd),       params(fn) = 11;
		elseif cmdmatch('nhelvnarrow',cmd),      params(fn) = 11;
		elseif cmdmatch('helveticanarrow',cmd),  params(fn) = 11;
		
		% Font size in sqrt(2) increments.
		elseif cmdmatch('bigger',cmd),  params(fs) = params(fs)*sqrt(2);
		elseif cmdmatch('larger',cmd),  params(fs) = params(fs)*sqrt(2);
		elseif cmdmatch('smaller',cmd), params(fs) = params(fs)/sqrt(2);
		
		% Colors.
		elseif cmdmatch('black',cmd),   params(cr:cb) = [0;0;0];
		elseif cmdmatch('white',cmd),   params(cr:cb) = [1;1;1];
		elseif cmdmatch('red',cmd),     params(cr:cb) = [1;0;0];
		elseif cmdmatch('green',cmd),   params(cr:cb) = [0;1;0];
		elseif cmdmatch('blue',cmd),    params(cr:cb) = [0;0;1];
		elseif cmdmatch('cyan',cmd),    params(cr:cb) = [0;1;1];
		elseif cmdmatch('magenta',cmd), params(cr:cb) = [1;0;1];
		elseif cmdmatch('yellow',cmd),  params(cr:cb) = [1;1;0];
		elseif cmdmatch('gray',cmd),    params(cr:cb) = [0.5;0.5;0.5];
		elseif cmdmatch('color',cmd)
			[arg,str] = strtok(str,'{}');
			str(1) = [];
			params(cr:cb) = sscanf(arg,'%f,%f,%f');
		
		% Absolute positioning in points.
		elseif cmdmatch('left',cmd)
			[arg,str] = strtok(str,'{}');
			str(1) = [];
			arg = sscanf(arg,'%f');
			params([x,nextX]) = params([x,nextX]) - arg;
		elseif cmdmatch('right',cmd)
			[arg,str] = strtok(str,'{}');
			str(1) = [];
			arg = sscanf(arg,'%f');
			params([x,nextX]) = params([x,nextX]) + arg;
		elseif cmdmatch('up',cmd)
			[arg,str] = strtok(str,'{}');
			str(1) = [];
			arg = sscanf(arg,'%f');
			params(y) = params(y) + arg;
		elseif cmdmatch('down',cmd)
			[arg,str] = strtok(str,'{}');
			str(1) = [];
			arg = sscanf(arg,'%f');
			params(y) = params(y) - arg;
		
		% Relative positioning in units of current font size.
		elseif cmdmatch('rleft',cmd)
			[arg,str] = strtok(str,'{}');
			str(1) = [];
			arg = sscanf(arg,'%f');
			params([x,nextX]) = params([x,nextX]) - arg*round(params(fs));
		elseif cmdmatch('rright',cmd)
			[arg,str] = strtok(str,'{}');
			str(1) = [];
			arg = sscanf(arg,'%f');
			params([x,nextX]) = params([x,nextX]) + arg*round(params(fs));
		elseif cmdmatch('rup',cmd)
			[arg,str] = strtok(str,'{}');
			str(1) = [];
			arg = sscanf(arg,'%f');
			params(y) = params(y) + arg*round(params(fs));
		elseif cmdmatch('rdown',cmd)
			[arg,str] = strtok(str,'{}');
			str(1) = [];
			arg = sscanf(arg,'%f');
			params(y) = params(y) - arg*round(params(fs));
		
		% Integral.
		elseif strcmp('int',cmd)
			[arg1,arg2,str] = getcargs(str);
			str = ['{\rdown{.25}\larger\sym ',242,...
					'}_{\rleft{.1}\rdown{.3}{',arg1,...
					'}}^{\rright{.2}\rup{.6}{',arg2,'}}',sp,str];
		
		% Summation.
		elseif strcmp('sum',cmd)
			[arg1,arg2,str] = getcargs(str);
			str = ['{\rdown{.2}\larger\sym ',229,'}_{\rdown{.1}{',arg1,...
					'}}^{\rup{.2}{',arg2,'}}',sp,str];
		
		% Product.
		elseif strcmp('prod',cmd)
			[arg1,arg2,str] = getcargs(str);
			str = ['{\rdown{.2}\larger\sym ',213,'}_{\rdown{.1}{',arg1,...
					'}}^{\rup{.2}{',arg2,'}}',sp,str];
		
		% Lowercase Greek letters.
		elseif strcmp('alpha',cmd),      str = ['{\sym a}',sp,str];
		elseif strcmp('beta',cmd),       str = ['{\sym b}',sp,str];
		elseif strcmp('gamma',cmd),      str = ['{\sym g}',sp,str];
		elseif strcmp('delta',cmd),      str = ['{\sym d}',sp,str];
		elseif strcmp('epsilon',cmd),    str = ['{\sym e}',sp,str];
		elseif strcmp('varepsilon',cmd), str = ['{\sym e}',sp,str];
		elseif strcmp('zeta',cmd),       str = ['{\sym z}',sp,str];
		elseif strcmp('eta',cmd),        str = ['{\sym h}',sp,str];
		elseif strcmp('theta',cmd),      str = ['{\sym q}',sp,str];
		elseif strcmp('vartheta',cmd),   str = ['{\sym J}',sp,str];
		elseif strcmp('iota',cmd),       str = ['{\sym i}',sp,str];
		elseif strcmp('kappa',cmd),      str = ['{\sym k}',sp,str];
		elseif strcmp('lambda',cmd),     str = ['{\sym l}',sp,str];
		elseif strcmp('mu',cmd),         str = ['{\sym m}',sp,str];
		elseif strcmp('nu',cmd),         str = ['{\sym n}',sp,str];
		elseif strcmp('xi',cmd),         str = ['{\sym x}',sp,str];
		elseif strcmp('pi',cmd),         str = ['{\sym p}',sp,str];
		elseif strcmp('varpi',cmd),      str = ['{\sym v}',sp,str];
		elseif strcmp('rho',cmd),        str = ['{\sym r}',sp,str];
		elseif strcmp('varrho',cmd),     str = ['{\sym r}',sp,str];
		elseif strcmp('sigma',cmd),      str = ['{\sym s}',sp,str];
		elseif strcmp('varsigma',cmd),   str = ['{\sym V}',sp,str];
		elseif strcmp('tau',cmd),        str = ['{\sym t}',sp,str];
		elseif strcmp('upsilon',cmd),    str = ['{\sym u}',sp,str];
		elseif strcmp('phi',cmd),        str = ['{\sym f}',sp,str];
		elseif strcmp('varphi',cmd),     str = ['{\sym j}',sp,str];
		elseif strcmp('chi',cmd),        str = ['{\sym c}',sp,str];
		elseif strcmp('psi',cmd),        str = ['{\sym y}',sp,str];
		elseif strcmp('omega',cmd),      str = ['{\sym w}',sp,str];
		
		% Uppercase Greek letters.
		elseif strcmp('Gamma',cmd),      str = ['{\sym G}',sp,str];
		elseif strcmp('Delta',cmd),      str = ['{\sym D}',sp,str];
		elseif strcmp('Theta',cmd),      str = ['{\sym Q}',sp,str];
		elseif strcmp('Lambda',cmd),     str = ['{\sym L}',sp,str];
		elseif strcmp('Xi',cmd),         str = ['{\sym X}',sp,str];
		elseif strcmp('Pi',cmd),         str = ['{\sym P}',sp,str];
		elseif strcmp('Sigma',cmd),      str = ['{\sym S}',sp,str];
		elseif strcmp('Upsilon',cmd),    str = ['{\sym ',161,'}',sp,str];
		elseif strcmp('varUpsilon',cmd), str = ['{\sym U}',sp,str];
		elseif strcmp('Phi',cmd),        str = ['{\sym F}',sp,str];
		elseif strcmp('Psi',cmd),        str = ['{\sym Y}',sp,str];
		elseif strcmp('Omega',cmd),      str = ['{\sym W}',sp,str];
		
		% Other TeX characters.
		elseif strcmp('forall',cmd),         str = ['{\sym ',34,'}',sp,str];
		elseif strcmp('exists',cmd),         str = ['{\sym ',36,'}',sp,str];
		elseif strcmp('cong',cmd),           str = ['{\sym ',64,'}',sp,str];
		elseif strcmp('perp',cmd),           str = ['{\sym ',350,'}',sp,str];
		elseif strcmp('bot',cmd),            str = ['{\sym ',350,'}',sp,str];
		elseif strcmp('leq',cmd),            str = ['{\sym ',163,'}',sp,str];
		elseif strcmp('infty',cmd),          str = ['{\sym ',165,'}',sp,str];
		elseif strcmp('leftrightarrow',cmd), str = ['{\sym ',171,'}',sp,str];
		elseif strcmp('leftarrow',cmd),      str = ['{\sym ',172,'}',sp,str];
		elseif strcmp('uparrow',cmd),        str = ['{\sym ',173,'}',sp,str];
		elseif strcmp('rightarrow',cmd),     str = ['{\sym ',174,'}',sp,str];
		elseif strcmp('downarrow',cmd),      str = ['{\sym ',175,'}',sp,str];
		elseif strcmp('degrees',cmd),        str = ['{\sym ',176,'}',sp,str];
		elseif strcmp('pm',cmd),             str = ['{\sym ',177,'}',sp,str];
		elseif strcmp('geq',cmd),            str = ['{\sym ',179,'}',sp,str];
		elseif strcmp('propto',cmd),         str = ['{\sym ',181,'}',sp,str];
		elseif strcmp('partial',cmd),        str = ['{\sym ',182,'}',sp,str];
		elseif strcmp('bullet',cmd),         str = ['{\sym ',183,'}',sp,str];
		elseif strcmp('div',cmd),            str = ['{\sym ',184,'}',sp,str];
		elseif strcmp('neq',cmd),            str = ['{\sym ',185,'}',sp,str];
		elseif strcmp('equiv',cmd),          str = ['{\sym ',186,'}',sp,str];
		elseif strcmp('approx',cmd),         str = ['{\sym ',187,'}',sp,str];
		elseif strcmp('dots',cmd),           str = ['{\sym ',188,'}',sp,str];
		elseif strcmp('aleph',cmd),          str = ['{\sym ',192,'}',sp,str];
		elseif strcmp('Im',cmd),             str = ['{\sym ',193,'}',sp,str];
		elseif strcmp('Re',cmd),             str = ['{\sym ',194,'}',sp,str];
		elseif strcmp('wp',cmd),             str = ['{\sym ',195,'}',sp,str];
		elseif strcmp('otimes',cmd),         str = ['{\sym ',196,'}',sp,str];
		elseif strcmp('oplus',cmd),          str = ['{\sym ',197,'}',sp,str];
		elseif strcmp('emptyset',cmd),       str = ['{\sym ',198,'}',sp,str];
		elseif strcmp('cap',cmd),            str = ['{\sym ',199,'}',sp,str];
		elseif strcmp('cup',cmd),            str = ['{\sym ',200,'}',sp,str];
		elseif strcmp('supset',cmd),         str = ['{\sym ',201,'}',sp,str];
		elseif strcmp('supseteq',cmd),       str = ['{\sym ',202,'}',sp,str];
		elseif strcmp('notsubset',cmd),      str = ['{\sym ',203,'}',sp,str];
		elseif strcmp('subset',cmd),         str = ['{\sym ',204,'}',sp,str];
		elseif strcmp('subseteq',cmd),       str = ['{\sym ',205,'}',sp,str];
		elseif strcmp('in',cmd),             str = ['{\sym ',206,'}',sp,str];
		elseif strcmp('notin',cmd),          str = ['{\sym ',207,'}',sp,str];
		elseif strcmp('angle',cmd),          str = ['{\sym ',208,'}',sp,str];
		elseif strcmp('nabla',cmd),          str = ['{\sym ',209,'}',sp,str];
		elseif strcmp('surd',cmd),           str = ['{\sym ',214,'}',sp,str];
		elseif strcmp('cdot',cmd),           str = ['{\sym ',215,'}',sp,str];
		elseif strcmp('neg',cmd),            str = ['{\sym ',216,'}',sp,str];
		elseif strcmp('lnot',cmd),           str = ['{\sym ',216,'}',sp,str];
		elseif strcmp('land',cmd),           str = ['{\sym ',217,'}',sp,str];
		elseif strcmp('lor',cmd),            str = ['{\sym ',218,'}',sp,str];
		elseif strcmp('Leftrightarrow',cmd), str = ['{\sym ',219,'}',sp,str];
		elseif strcmp('Leftarrow',cmd),      str = ['{\sym ',220,'}',sp,str];
		elseif strcmp('Uparrow',cmd),        str = ['{\sym ',221,'}',sp,str];
		elseif strcmp('Rightarrow',cmd),     str = ['{\sym ',222,'}',sp,str];
		elseif strcmp('Downarrow',cmd),      str = ['{\sym ',223,'}',sp,str];
		elseif strcmp('diamond',cmd),        str = ['{\sym ',224,'}',sp,str];
		elseif strcmp('langle',cmd),         str = ['{\sym ',225,'}',sp,str];
		elseif strcmp('lceil',cmd),          str = ['{\sym ',233,'}',sp,str];
		elseif strcmp('lfloor',cmd),         str = ['{\sym ',235,'}',sp,str];
		elseif strcmp('vert',cmd),           str = ['{\sym ',239,'}',sp,str];
		elseif strcmp('rangle',cmd),         str = ['{\sym ',241,'}',sp,str];
		elseif strcmp('rceil',cmd),          str = ['{\sym ',249,'}',sp,str];
		elseif strcmp('rfloor',cmd),         str = ['{\sym ',251,'}',sp,str];

		elseif strcmp('Vert',cmd),     str = ['{\sym ',[247,231],'}',sp,str];
		
		% Non-TeX characters and TeX-like constructs that don't work quite
		% like they do in TeX.
		elseif strcmp('+',cmd),         str = ['{\sym +}',sp,str];
		elseif strcmp('-',cmd),         str = ['{\sym -}',sp,str];
		elseif strcmp('=',cmd),         str = ['{\sym =}',sp,str];
		elseif strcmp('>',cmd),         str = ['{\sym >}',sp,str];
		elseif strcmp('<',cmd),         str = ['{\sym <}',sp,str];
		elseif strcmp('|',cmd),         str = ['{\sym |}',sp,str];
		elseif strcmp('therefore',cmd), str = ['{\sym ',348,'}',sp,str];
		elseif strcmp('prime',cmd),     str = ['{\sym ',162,'}',sp,str];
		elseif strcmp('slash',cmd),     str = ['{\sym ',164,'}',sp,str];
		elseif strcmp('dprime',cmd),    str = ['{\sym ',178,'}',sp,str];
		elseif strcmp('mult',cmd),      str = ['{\sym ',180,'}',sp,str];
		elseif strcmp('horiz',cmd),     str = ['{\sym ',190,'}',sp,str];
		
		% Diacritics.
		elseif strcmp('grave',cmd)
			accent = gACCENT_CODES(1);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('acute',cmd)
			accent = gACCENT_CODES(2);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('ddot',cmd)
			accent = gACCENT_CODES(3);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('hat',cmd)
			accent = gACCENT_CODES(4);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('tilde',cmd)
			accent = gACCENT_CODES(5);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('bar',cmd)
			accent = gACCENT_CODES(6);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('breve',cmd)
			accent = gACCENT_CODES(7);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('dot',cmd)
			accent = gACCENT_CODES(8);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('check',cmd)
			accent = gACCENT_CODES(9);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('Grave',cmd)
			accent = gACCENT_CODES(1);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\rup{.2}\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('Acute',cmd)
			accent = gACCENT_CODES(2);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\rup{.2}\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('Ddot',cmd)
			accent = gACCENT_CODES(3);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\rup{.2}\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('Hat',cmd)
			accent = gACCENT_CODES(4);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\rup{.2}\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('Tilde',cmd)
			accent = gACCENT_CODES(5);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\rup{.2}\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('Bar',cmd)
			accent = gACCENT_CODES(6);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\rup{.2}\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('Breve',cmd)
			accent = gACCENT_CODES(7);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\rup{.2}\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('Dot',cmd)
			accent = gACCENT_CODES(8);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\rup{.2}\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		elseif strcmp('Check',cmd)
			accent = gACCENT_CODES(9);
			ww = gFONT_METRICS(accent+1,fm(params(fn),...
					colLut(params(fa),params(fw))))*round(params(fs))/1000;
			lr = [lastWidth,ww]*[1 1;1 -1]/2;
			str = ['{\rup{.2}\left{',num2str(lr(1)),'}',accent,...
					'\right{',num2str(lr(2)),'}}',sp,str];
		
		else
			% Command is unknown.
			delete(objList)
			delete(anchor)
			error(['Unrecognized command: ',cmd])
		
		end
	else
		% str(1) is not one of '{}^_\' so it must be the beginning of text.
		params(x) = params(nextX);
		params(mode) = 0;
		[newStr,str] = strtok(str,'\{}^_');
		newStr = setstr(rem(newStr,256));
		newStr1 = newStr + 1;
		
		% Compute character widths.
		strLen = length(newStr);
		fmSel = fm(params(fn),colLut(params(fa),params(fw)));
		widths = gFONT_METRICS(newStr1,fmSel)*round(params(fs))/1000;
		lastWidth = widths(length(widths));
		
		% Compute kern correction, kc.
		kc = zeros(strLen-1,1);
		for k = 1:strLen-1
			kc(k) = gKERNING_DATA((fmSel-1)*256 + newStr1(k),newStr1(k+1));
		end
		kc = kc*round(params(fs))/1000;
		
		xx = params(x) + cumsum([0;widths(1:strLen-1) + kc]);
		yy = params(y(ones(strLen,1)));
		
		if strLen == 1
			newObj = text('Position',  [xx,yy],...
					'String',              newStr,...
					'FontAngle',           fontanglelist(params(fa),:),...
					'FontName',            deblank(fontnamelist(params(fn),:)),...
					'FontSize',            round(params(fs)),...
					'FontWeight',          fontweightlist(params(fw),:),...
					'Units',               'points',...
					'Rotation',            0,...
					'HorizontalAlignment', 'left',...
					'VerticalAlignment',   'baseline',...
					'Color',               params(cr:cb),...
					'EraseMode',           eraseMode,...
					'ButtonDownFcn',       buttonDownFcn,...
					'Clipping',            clipping,...
					'Interruptible',       interruptible,...
					'Visible',             visible);
		else
			newObj = text(xx,yy,newStr',...
					'FontAngle',           fontanglelist(params(fa),:),...
					'FontName',            deblank(fontnamelist(params(fn),:)),...
					'FontSize',            round(params(fs)),...
					'FontWeight',          fontweightlist(params(fw),:),...
					'Units',               'points',...
					'Rotation',            0,...
					'HorizontalAlignment', 'left',...
					'VerticalAlignment',   'baseline',...
					'Color',               params(cr:cb),...
					'EraseMode',           eraseMode,...
					'ButtonDownFcn',       buttonDownFcn,...
					'Clipping',            clipping,...
					'Interruptible',       interruptible,...
					'Visible',             visible);
		end
		objList = [objList,newObj'];
		heightList = [heightList,yy'];
		xDistance = [xDistance,xx'];
		params(nextX) = xx(strLen) + lastWidth;
		params(x) = params(nextX);
		
		% The vertical position of the styled text is based on the first
		% character of the text.
		if first
			set(anchor,'FontAngle',fontanglelist(params(fa),:),...
					'FontName',fontnamelist(params(fn),:),...
					'FontSize',round(params(fs)),...
					'FontWeight',fontweightlist(params(fw),:))
			set(anchor,'Units','points')
			ex1 = get(anchor,'Extent');
			set(anchor,'VerticalAlignment','baseline')
			ex2 = get(anchor,'Extent');
			set(anchor,'Units',anchorUnits,'VerticalAlignment',vertAlign)
			hOffset = ex1(2) - ex2(2);
			first = 0;
		end
	end
end
totalWidth = params(nextX);
numSegments = length(objList);

% Compute new x and y locations for each text object based on
% justification and rotation.
r = rotation*pi/180;
if cmdmatch('left',horizAlign)
	t = 0;
elseif cmdmatch('center',horizAlign)
	t = totalWidth/2;
elseif cmdmatch('right',horizAlign)
	t = totalWidth;
end
xList = x0 + (xDistance - t)*cos(r) - (heightList + hOffset)*sin(r);
yList = y0 + (xDistance - t)*sin(r) + (heightList + hOffset)*cos(r);

for i = 1:numSegments
	set(objList(i),'Position',[xList(i),yList(i)],'Rotation',rotation);
end

% Anchor text object is invisible, but by setting the rotation we can
% use get(stext object handle).  UserData contains a type flag (0 =
% normal, 1 = x-label, 2 = y-label, 3 = z-label, 4 = title), the
% location of the anchor object in points and a list of the handles
% to the text objects that make up the styled text object.

set(anchor,'Rotation',rotation,'UserData',[0,x0,y0,objList])
delete(oldObjList)
