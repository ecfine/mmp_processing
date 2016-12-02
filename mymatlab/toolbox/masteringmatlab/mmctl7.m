% mmctl7.m

Hc_fcolor = uicontrol(gcf,'Style','popupmenu',...
    'Position',[20 20 80 20],...
    'String','Black|Red|Yellow|Green|Cyan|Blue|Magenta|White',...
    'Value',1,...
    'UserData',[[0 0 0];...
                [1 0 0];...
                [1 1 0];...
                [0 1 0];...
                [0 1 1];...
                [0 0 1];...
                [1 0 1];...
                [1 1 1]],...
    'CallBack',[...
        'UD=get(Hc_fcolor,''UserData'');',...
        'set(gcf,''Color'',UD(get(Hc_fcolor,''Value''),:))']);