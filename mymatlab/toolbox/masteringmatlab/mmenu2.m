% mmenu2.m

Hm_top = uimenu('Label','Example');
Hm_box = uimenu(Hm_top,'Label','Axis Box',...
           'CallBack',[...
              'if strcmp(get(gca,''Box''),''on''),',...
                 'set(gca,''Box'',''off''),',...
                 'set(Hm_box,''Checked'',''off''),',...
              'else,',...
                 'set(gca,''Box'',''on''),',...
                 'set(Hm_box,''Checked'',''on''),',...
              'end']);

