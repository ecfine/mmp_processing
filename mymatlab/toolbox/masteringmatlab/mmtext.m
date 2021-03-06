function mmtext(arg)
%MMTEXT Place and Drag Text with Mouse.
% MMTEXT waits for a mouse click on a text object,
% in the current figure then allows it to be dragged
% while the mouse button remains down.
% MMTEXT('whatever') places the string 'whatever' on
% the current axes and allows it to be dragged.
%
% MMTEXT becomes inactive after the move is complete or
% no text object is selected.

% D.C. Hanselman, University of Maine, Orono, ME, 04469
% 6/22/95
% Copyright (c) 1996 by Prentice-Hall, Inc.

if ~nargin,arg=0;end

if isstr(arg)  % user entered text to be placed
	Ht=text('Units','normalized',...
			'Position',[.05 .05],...
			'String',arg,...
			'HorizontalAlignment','left',...
			'VerticalAlignment','baseline');
	mmtext(0)  % call mmtext again to drag it
	
elseif arg==0  % initial call, select text for dragging
	Hf=mmgcf;
	if isempty(Hf), error('No Figure Available.'), end
	set(Hf,	'BackingStore','off',...
			'WindowButtonDownFcn','mmtext(1)')
	figure(Hf)  % bring figure forward

elseif arg==1 & strcmp(get(gco,'type'),'text') % text object selected
	set(gco,'Units','data',...
			'HorizontalAlignment','left',...
			'VerticalAlignment','baseline',...
			'EraseMode','xor');
	set(gcf,'Pointer','topr',...
			'WindowButtonMotionFcn','mmtext(2)',...
			'WindowButtonUpFcn','mmtext(99)')
			
elseif arg==2  % dragging text object
	cp=get(gca,'CurrentPoint');
	set(gco,'Position',cp(1,1:3))
	
elseif arg==99  % mouse button up, reset everything
	set(gco,'Erasemode','normal')
	set(gcf,'WindowButtonDownFcn','',...
			'WindowButtonMotionFcn','',...
			'WindowButtonUpFcn','',...
			'Pointer','arrow',...
			'Units','pixels',...
			'BackingStore','on')
else		% incorrect object selected, reset and abort
	set(gcf,'WindowButtonDownFcn','',...
			'WindowButtonMotionFcn','',...
			'WindowButtonUpFcn','',...
			'Pointer','arrow',...
			'Units','pixels',...
			'BackingStore','on')
end
