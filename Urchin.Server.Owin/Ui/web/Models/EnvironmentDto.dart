﻿import 'dart:html';
import 'dart:convert';
import 'dart:async';

import 'Dto.dart';

class EnvironmentDto extends Dto
{
	List<SecurityRuleDto> securityRules;

	EnvironmentDto(Map json)
	{
		Reload(json);
	}

	void Reload(Map json)
	{
		startLoading(json);

		securityRules = new List<SecurityRuleDto>();
    
		List jsonRules = json['securityRules'];
		if (jsonRules != null)
		{
			for (Map r in jsonRules)
			{
				securityRules.add(new SecurityRuleDto(r));
			}
		}

		finishedLoading();
	}

	String get name => json['name'];
	set name(String value) { setProperty('name', value); }
  
	int get version => json['version'];
	set version(int value) { setProperty('version', value); }
  
	List<String> get machines => json['machines'];
	set machines(List<String> value) { setProperty('machines', value); }
}
