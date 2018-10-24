select
concat("'",pi.identifier) as kh_number,
pn.family_name last_name,
pn.given_name first_name,
p.birthdate as dob,
p.gender as sex,
bk.Operation,
bk.Surgeon,
bk.Appointment_Date as DoO,
cost.*
from
(
select
c.patient_id,
adm.Primary,
adm.Secondary,
adm.encounter_datetime as DoA,
DATE_FORMAT(adm.date_of_discharge, '%d-%m-%Y') as date_of_discharge,
adm.location,
adm.visit_id,
c.stay_cost,
c.procedure_cost,
c. anaesthesia_cost,
c.date_created as date_of_charge,
c.doctor_cost,
c.meds_cost,
c.lab_cost,
c.xray_cost,
c.supplies_cost,
c.file_cost,
c.follow_up_cost,
c.comments,
a.account_name,
pc.*
from bkkh_charges c
left outer join (
SELECT
charges_id as charges_id,
date(MAX(payment_date)) as payment_date,
charge_account_id,
SUM(if(mode_of_payment_id=1, amount_paid, '')) as NHIF,
SUM(if(mode_of_payment_id=2, amount_paid, '')) as 'Other Individual',
SUM(if(mode_of_payment_id=3, amount_paid, '')) as 'Government Sponsored',
SUM(if(mode_of_payment_id=4, amount_paid, '')) as 'NGO Sponsored',
SUM(if(mode_of_payment_id=5, amount_paid, '')) as 'Insurance',
SUM(if(mode_of_payment_id=6, amount_paid, '')) as 'Needy Fund',
SUM(if(mode_of_payment_id=7, amount_paid, '')) as 'WATSI',
SUM(if(mode_of_payment_id=8, amount_paid, '')) as 'KH Debt Account',
SUM(amount_paid) as Total_Paid,
if(charge_account_id=1, 'Neuro', '') as 'BK Neuro',
if(charge_account_id=2, 'PedsSurg', '') as 'BK Peds Surg',
if(charge_account_id=3, 'SmileTrain', '') as 'BK Smile Train'
from bkkh_payment
group by charges_id
) pc  on c.charges_id = pc.charges_id
inner join (

select
d.patient_id as person_id,
d.encounter_id,
d.visit_id,
d.location,
d.encounter_datetime,
d.date_of_discharge,
IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=0, SUBSTRING_INDEX(d.diagnosis,'|',1), '') AS 'Primary',
IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=1, SUBSTRING_INDEX(SUBSTRING_INDEX(d.diagnosis,'|',2),'|',-1), '') as 'Secondary',
IF(ROUND ((LENGTH(d.diagnosis)- LENGTH(REPLACE(d.diagnosis, "|", "") )) / LENGTH("|"))>=2, SUBSTRING_INDEX(d.diagnosis,'|',-1), '') as dx3
from
(
select e.patient_id, e.encounter_id,
max(if(o.concept_id=1641, date(o.value_datetime), "")) as date_of_discharge,
group_concat(if(o.concept_id=6042, cn.name, null) order by obs_id separator '|') as diagnosis,
e.visit_id, e.encounter_datetime, l.name as location from encounter e
inner join location l on l.location_id=e.location_id
inner join obs o on o.person_id=e.patient_id and o.encounter_id = e.encounter_id
left outer join concept_name cn on cn.concept_id=o.value_coded and cn.voided=0 and cn.concept_name_type='FULLY_SPECIFIED' and cn.locale='en'
inner join
(
    select encounter_type, uuid,name from form where
    uuid in('fc803dd8-aa3c-4de9-bd87-64ea7c947ae4')
) f on f.encounter_type=e.encounter_type
where o.concept_id in (6042, 1641)
group by e.encounter_id
having diagnosis is not null
) d
) adm on adm.visit_id = c.visit_id
inner join bkkh_charge_account a on a.charge_account_id = pc.charge_account_id
) cost
left outer join
(
select
e.encounter_id,
patient_id,
concat(p.given_name,' ',p.family_name) as Surgeon,
e.encounter_datetime,
max(if(o.concept_id=5096, o.value_datetime, '')) as Appointment_Date,
max(if(o.concept_id=1651,cn.name , '')) as Operation,
e.creator
from obs o
inner join encounter e on e.encounter_id=o.encounter_id and e.voided=0
inner join person_name p on e.creator= p.person_id
left outer join concept_name cn on cn.concept_id=o.value_coded and cn.voided=0 and cn.concept_name_type='FULLY_SPECIFIED' and cn.locale='en'
where o.concept_id in (5096, 1651) and e.encounter_type=14
group by e.encounter_id
) bk on bk.patient_id = cost.patient_id and bk.Appointment_Date between date_add(cost.DoA, interval -2 DAY) and date_add(cost.DoA, interval 2 DAY)
inner join person p on p.person_id=cost.patient_id and p.voided=0
inner join person_name pn on pn.person_id = p.person_id and pn.voided=0
left outer join patient_identifier pi on pi.patient_id = cost.patient_id and pi.identifier_type=4 and pi.voided=0
having date_of_charge between :startDate and :endDate
;

